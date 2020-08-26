// SPDX-License-Identifier: MIT

pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ChainLink is ERC20 {

    constructor () public ERC20("ChainLink", "LINK") {
        _mint(msg.sender, 1000000000 * (10 ** uint256(decimals())));
    }
}