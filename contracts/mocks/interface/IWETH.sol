pragma solidity 0.4.18;

contract IWETH {
    function() public payable {
        deposit();
    }

    function deposit() public payable;

    function withdraw(uint wad) public;

    function totalSupply() public view returns (uint);

    function approve(address guy, uint wad) public returns (bool);

    function transfer(address dst, uint wad) public returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint wad
    ) public returns (bool);
}


interface TokenInterfaceV5 {
    function burn(address, uint256) external;

    function mint(address, uint256) external;

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function hasRole(bytes32, address) external view returns (bool);

    function approve(address, uint256) external returns (bool);

    function allowance(address, address) external view returns (uint256);
}
