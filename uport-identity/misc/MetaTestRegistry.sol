pragma solidity 0.4.15;


// This contract is only used for testing purposes.
// 存储一个地址和无符号整数映射的键值对
contract MetaTestRegistry {

    mapping(address => uint) public registry;

    function register(address sender, uint x) {
        registry[sender] = x;
    }
}
