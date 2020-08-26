// SPDX-License-Identifier: MIT

pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Multiplier is ERC20 {

    constructor () public ERC20("Multiplier", "MXX") {
        _setupDecimals(8);
        _mint(msg.sender, 9000000000 * (10 ** uint256(decimals())));
    }
}