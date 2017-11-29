pragma solidity 0.4.15;


contract Migrations {
  address public owner;
  uint public last_completed_migration;
  
  // 限制非合约拥有者访问或者更新版本号
  modifier restricted() {
    if (msg.sender == owner) _;
  }

  // 构造函数，设定owner为合约部署者
  function Migrations() {
    owner = msg.sender;
  }

  // 完成版本时设定版本号以作更新记录之用
  function setCompleted(uint completed) restricted {
    last_completed_migration = completed;
  }

  // 把一个已创建好的版本合约的last_completed_migration设定为这个版本合约的版本号
  // 用于记录已完成的版本，即每个版本对应一份upgraded合约
  function upgrade(address new_address) restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}