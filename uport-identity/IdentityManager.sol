pragma solidity 0.4.15;
import "./Proxy.sol";


contract IdentityManager {
    uint adminTimeLock;
    uint userTimeLock;
    uint adminRate;

    event LogIdentityCreated(
        address indexed identity,
        address indexed creator,
        address owner,
        address indexed recoveryKey);

    event LogOwnerAdded(
        address indexed identity,
        address indexed owner,
        address instigator);

    event LogOwnerRemoved(
        address indexed identity,
        address indexed owner,
        address instigator);

    event LogRecoveryChanged(
        address indexed identity,
        address indexed recoveryKey,
        address instigator);

    event LogMigrationInitiated(
        address indexed identity,
        address indexed newIdManager,
        address instigator);

    event LogMigrationCanceled(
        address indexed identity,
        address indexed newIdManager,
        address instigator);

    event LogMigrationFinalized(
        address indexed identity,
        address indexed newIdManager,
        address instigator);

    mapping(address => mapping(address => uint)) owners;
    mapping(address => address) recoveryKeys;
    mapping(address => mapping(address => uint)) limiter;
    mapping(address => uint) public migrationInitiated;
    mapping(address => address) public migrationNewAddress;

    modifier onlyOwner(address identity) {
        require(isOwner(identity, msg.sender));
        _;
    }

    modifier onlyOlderOwner(address identity) {
        require(isOlderOwner(identity, msg.sender));
        _;
    }

    modifier onlyRecovery(address identity) {
        require(recoveryKeys[identity] == msg.sender);
        _;
    }

    // 对于owner和recovery操作频率的限制
    modifier rateLimited(address identity) {
        require(limiter[identity][msg.sender] < (now - adminRate));
        limiter[identity][msg.sender] = now;
        _;
    }

    modifier validAddress(address addr) { //protects against some weird attacks
        require(addr != address(0));
        _;
    }

    /// @dev Contract constructor sets initial timelock limits
    /// @param _userTimeLock Time before new owner added by recovery can control proxy
    /// @param _adminTimeLock Time before new owner can add/remove owners
    /// @param _adminRate Time period used for rate limiting a given key for admin functionality
    /// 构造函数设置主要的时间限制，将用户集中到同一个管理合约
    /// _userTimeLock限制一个新owner从被recovery添加到实际控制proxy合约的时间
    /// _adminTimeLock限制一个新owner可以增加或删除owners的时间
    /// _adminRate是对于管理功能的操作频率限制
    function IdentityManager(uint _userTimeLock, uint _adminTimeLock, uint _adminRate) {
        adminTimeLock = _adminTimeLock;
        userTimeLock = _userTimeLock;
        adminRate = _adminRate;
    }

    /// @dev Creates a new proxy contract for an owner and recovery
    /// @param owner Key who can use this contract to control proxy. Given full power
    /// @param recoveryKey Key of recovery network or address from seed to recovery proxy
    /// Gas cost of 289,311
    /// 创建一个新的Owned为这个合约的proxy合约，并指定它的owner字段和recovery字段
    /// 因此注册为中心化做法，由机构帮用户实现
    function createIdentity(address owner, address recoveryKey) public validAddress(recoveryKey) {
        Proxy identity = new Proxy();
        // 赋予owner对于proxy的控制权，立刻生效
        owners[identity][owner] = now - adminTimeLock; // This is to ensure original owner has full power from day one
        recoveryKeys[identity] = recoveryKey;
        LogIdentityCreated(identity, msg.sender, owner,  recoveryKey);
    }

    /// @dev Allows a user to transfer control of existing proxy to this contract. Must come through proxy
    /// @param owner Key who can use this contract to control proxy. Given full power
    /// @param recoveryKey Key of recovery network or address from seed to recovery proxy
    /// Note: User must change owner of proxy to this contract after calling this
    /// 用于用户提前部署好proxy合约，然后把控制权Owned[此时等同于owner]注册到这个合约并通过这个合约管理身份proxy
    /// 这个函数通过Proxy合约forward来调用
    /// 最后应该调用Owned的transfer来把proxy的控制权交给这份合约
    function registerIdentity(address owner, address recoveryKey) public validAddress(recoveryKey) {
        require(recoveryKeys[msg.sender] == 0); // Deny any funny business
        // 赋予owner对于proxy的控制权，立刻生效
        owners[msg.sender][owner] = now - adminTimeLock; // This is to ensure original owner has full power from day one
        recoveryKeys[msg.sender] = recoveryKey;
        LogIdentityCreated(msg.sender, msg.sender, owner, recoveryKey);
    }

    /// @dev Allows a user to forward a call through their proxy.
    /// 这份合约在掌握proxy的控制权后，帮助用户实现应该属于他们的proxy合约的forward功能
    function forwardTo(Proxy identity, address destination, uint value, bytes data) public onlyOwner(identity) {
        identity.forward(destination, value, data);
    }

    /// @dev Allows an olderOwner to add a new owner instantly
    /// 
    function addOwner(Proxy identity, address newOwner) public onlyOlderOwner(identity) rateLimited(identity) {
        owners[identity][newOwner] = now - userTimeLock;
        LogOwnerAdded(identity, newOwner, msg.sender);
    }

    /// @dev Allows a recoveryKey to add a new owner with userTimeLock waiting time
    function addOwnerFromRecovery(Proxy identity, address newOwner) public onlyRecovery(identity) rateLimited(identity) {
        require(!isOwner(identity, newOwner));
        owners[identity][newOwner] = now;
        LogOwnerAdded(identity, newOwner, msg.sender);
    }

    /// @dev Allows an owner to remove another owner instantly
    function removeOwner(Proxy identity, address owner) public onlyOlderOwner(identity) rateLimited(identity) {
        delete owners[identity][owner];
        LogOwnerRemoved(identity, owner, msg.sender);
    }

    /// @dev Allows an owner to change the recoveryKey instantly
    function changeRecovery(Proxy identity, address recoveryKey) public
        onlyOlderOwner(identity)
        rateLimited(identity)
        validAddress(recoveryKey)
    {
        recoveryKeys[identity] = recoveryKey;
        LogRecoveryChanged(identity, recoveryKey, msg.sender);
    }

    /// @dev Allows an owner to begin process of transfering proxy to new IdentityManager
    function initiateMigration(Proxy identity, address newIdManager) public
        onlyOlderOwner(identity)
        validAddress(newIdManager)
    {
        migrationInitiated[identity] = now;
        migrationNewAddress[identity] = newIdManager;
        LogMigrationInitiated(identity, newIdManager, msg.sender);
    }

    /// @dev Allows an owner to cancel the process of transfering proxy to new IdentityManager
    function cancelMigration(Proxy identity) public onlyOwner(identity) {
        address canceledManager = migrationNewAddress[identity];
        delete migrationInitiated[identity];
        delete migrationNewAddress[identity];
        LogMigrationCanceled(identity, canceledManager, msg.sender);
    }

    /// @dev Allows an owner to finalize migration once adminTimeLock time has passed
    /// WARNING: before transfering to a new address, make sure this address is "ready to recieve" the proxy.
    /// Not doing so risks the proxy becoming stuck.
    function finalizeMigration(Proxy identity) public onlyOlderOwner(identity) {
        require(migrationInitiated[identity] != 0 && migrationInitiated[identity] + adminTimeLock < now);
        address newIdManager = migrationNewAddress[identity];
        delete migrationInitiated[identity];
        delete migrationNewAddress[identity];
        identity.transfer(newIdManager);
        delete recoveryKeys[identity];
        delete owners[identity][msg.sender];
        LogMigrationFinalized(identity, newIdManager, msg.sender);
    }

    function isOwner(address identity, address owner) public constant returns (bool) {
        return (owners[identity][owner] > 0 && (owners[identity][owner] + userTimeLock) <= now);
    }

    function isOlderOwner(address identity, address owner) public constant returns (bool) {
        return (owners[identity][owner] > 0 && (owners[identity][owner] + adminTimeLock) <= now);
    }

    function isRecovery(address identity, address recoveryKey) public constant returns (bool) {
        return recoveryKeys[identity] == recoveryKey;
    }
}