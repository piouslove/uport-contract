pragma solidity 0.4.15;


contract Owned {
    address public owner;
    modifier onlyOwner() {
        require(isOwner(msg.sender));
        _;
    }

    // 设定部署合约者为owner
    function Owned() { owner = msg.sender; }

    // 验证一个地址是否为owner
    function isOwner(address addr) public returns(bool) { return addr == owner; }

    // owner可以转移控制权
    function transfer(address _owner) public onlyOwner {
        if (_owner != address(this)) {
            owner = _owner;
        }
    }
}