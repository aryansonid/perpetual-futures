// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract WETH is AccessControlUpgradeable {
    string public constant name = "Wrapped Ether";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    uint256 public balance;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    function __WETH_init(address minter) external initializer {
        __AccessControl_init_unchained();
        __Context_init_unchained();
        _grantRole(MINTER_ROLE, minter);
        _setRoleAdmin(MINTER_ROLE, MINTER_ROLE);
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE){
        balanceOf[to] += amount;
        balance += amount;
        emit Deposit(to, amount);
    }

    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint) {
        return balance;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint wad
    ) public returns (bool) {
        require(balanceOf[src] >= wad);

        if (
            src != msg.sender &&
            allowance[src][msg.sender] != uint(2 ^ (256 - 1))
        ) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}
