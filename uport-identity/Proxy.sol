pragma solidity 0.4.15;
import "./libs/Owned.sol";

// Proxy继承自Owned
contract Proxy is Owned {
    event LogForwarded (address indexed destination, uint value, bytes data);
    event LogReceived (address indexed sender, uint value);

    // 允许proxy合约收取以太币
    function () payable { LogReceived(msg.sender, msg.value); }

    // 通过proxy合约发送交易调用合约等
    function forward(address destination, uint value, bytes data) public onlyOwner {
        require(destination.call.value(value)(data));
        LogForwarded(destination, value, data);
    }
}