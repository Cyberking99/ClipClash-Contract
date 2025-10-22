// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClashToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    
    uint256 public totalMinted;

    event TokensMinted(address indexed to, uint256 amount);

    constructor() ERC20("ClashToken", "CLASH") Ownable(msg.sender) {}

    function mint(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(totalMinted + _amount <= MAX_SUPPLY, "Exceeds max supply");

        totalMinted += _amount;
        _mint(_to, _amount);

        emit TokensMinted(_to, _amount);
    }
    
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
