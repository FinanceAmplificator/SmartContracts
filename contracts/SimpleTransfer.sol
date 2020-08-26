//SPDX-License-Identifier: MIT
pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract SimpleTransfer {
  constructor() public {
  }

  using SafeERC20 for ERC20;

  function transferERC20(address _ERC20Address, address receiver, uint256 value) public {
    ERC20(_ERC20Address).safeTransferFrom(msg.sender, receiver, value);
  }
}
