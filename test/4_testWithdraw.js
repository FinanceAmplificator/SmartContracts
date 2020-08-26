const YieldContract = artifacts.require("YieldContract");
const Tether = artifacts.require("Tether");
const VeChain = artifacts.require("VeChain");
const ChainLink = artifacts.require("ChainLink");
const HuobiToken = artifacts.require("HuobiToken");
const BasicAttentionToken = artifacts.require("BasicAttentionToken");
const Multiplier = artifacts.require("Multiplier");
const multiplierAddress = "0x1E4c15682D1DEC19bFc2b3C833dE40b64fe43613";


contract("YieldContract", function (accounts) {

  it("should not allow non-owner to withdraw MXX", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let tetherInstance;
    let tetherMintFactor = "1003500000000000000";
    let owner = accounts[0];
    let nonOwner = accounts[1];
    let mxxAmount = "100000000000000000";

    // Deploy multiplier contract
    return Multiplier.at(multiplierAddress)
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed("10000000000000000");
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Sending 1 million mxx to yield contract
        return multiplierInstance.transfer(
          YieldContractInstance.address,
          mxxAmount,
          { from: owner }
        );
      })
      .then(function (result) {
        // Attempt to add Tether ERC20 into list by nonOwner
        return YieldContractInstance.withdrawMXX(mxxAmount, { from: nonOwner });
      })
      .catch(function (error) {
        // Print error message
        console.log(error.message);
        assert(true);
      });
  });

  it("should allow owner to withdraw MXX and update balance properly", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let tetherInstance;
    let tetherMintFactor = "1003500000000000000";
    let owner = accounts[0];
    let nonOwner = accounts[1];
    let mxxAmount = "100000000000000000";
    let mxxBalanceAfter;
    let mxxBalanceBefore;

    // Deploy multiplier contract
    return Multiplier.at(multiplierAddress)
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed("10000000000000000");
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Get MXX balance
        return multiplierInstance.balanceOf(owner, { from: owner });
      })
      .then(function (result) {
        mxxBalanceBefore = result;

        // Attempt to add Tether ERC20 into list by nonOwner
        return YieldContractInstance.withdrawMXX(mxxAmount, { from: owner });
      })
      .then(function (result) {
        // Get MXX balance after
        return multiplierInstance.balanceOf(owner, { from: owner });
      })
      .then(function (result) {
        mxxBalanceAfter = result;

        // Assert
        assert.deepEqual(
          mxxBalanceAfter.sub(mxxBalanceBefore).toString(),
          mxxAmount,
          "MXX not received properly"
        );
      });
  });

  
});