// SPDX-License-Identifier: MIT

pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HuobiToken is ERC20 {

    constructor () public ERC20("HuobiToken", "HT") {
        _mint(msg.sender, 5000000 * (10 ** uint256(decimals())));
    }
}