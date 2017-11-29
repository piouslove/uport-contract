// This contract is only used for testing purposes.
pragma solidity 0.4.15;


contract TestRegistry {

    mapping(address => uint) public registry;
    mapping(address => string) public strRegistry;

    function register(uint x) {
        registry[msg.sender] = x;
    }

    // 测试字符串的存储使用
    function reallyLongFunctionName(
        uint with,
        address many,
        string strange,
        uint params
    ) {
        strRegistry[many] = strange;
        registry[many] = with;
        registry[many] = params;
    }

    function testThrow() {
        revert();
    }
}