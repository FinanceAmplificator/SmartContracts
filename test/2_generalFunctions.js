const YieldContract = artifacts.require("YieldContract");
const Tether = artifacts.require("Tether");
const VeChain = artifacts.require("VeChain");
const ChainLink = artifacts.require("ChainLink");
const HuobiToken = artifacts.require("HuobiToken");
const BasicAttentionToken = artifacts.require("BasicAttentionToken");
const Multiplier = artifacts.require("Multiplier");

contract("YieldContract", function (accounts) {

  
  it("should get interest for 90 days tenure", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let expectedInterestRate = "500000"; 
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to get interest rate for 90 days tenure
      return YieldContractInstance.tenureApyMap.call(90,{from: nonOwner});
    }).then(function(result){

      // Assert
      assert.deepEqual(result.toString(),expectedInterestRate,"Interest rate not returned properly");
    });
  });
  
  it("should return 0 for 45 day interest rate", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let expectedInterestRate = "0"; 
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to get interest rate for 45 days tenure
      return YieldContractInstance.tenureApyMap.call(45,{from: nonOwner});
    }).then(function(result){

      // Assert
      assert.deepEqual(result.toString(),expectedInterestRate,"0 interest rate not returned properly");
    });
  });
  
  it("should not allow non owner to set interest rate", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let tenureDays = 90;
    let newInterestRate = "10000000000000000000"; 
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to set interest rate for 90 days tenure by non owner
      return YieldContractInstance.setInterest(tenureDays, newInterestRate, { from: nonOwner });
    }).catch(function(error){

      // Print error
      console.log(error.message);
      assert(true);
    });
  });
  
  it("should allow owner to set interest rate and return it properly", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let tenureDays = 45;
    let newInterestRate = "10000000000000000000"; 
    let owner = accounts[0];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to set interest rate by owner
      return YieldContractInstance.setInterest(tenureDays, newInterestRate, { from: owner });
    }).then(function(result){

      // Get interest rate details
      return YieldContractInstance.tenureApyMap.call(tenureDays,{from: owner});
    }).then(function(result){

      // Assert
      assert.deepEqual(result.toString(),newInterestRate,"New interest rate not returned properly");
    });
  });
  
  it("should get yield contract fee", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let expectedYieldContractFee = "100000"; 
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to get contract fee
      return YieldContractInstance.contractFee.call({from: nonOwner});
    }).then(function(result){

      // Assert
      assert.deepEqual(result.toString(),expectedYieldContractFee,"Yield contract fee not returned properly");
    });
  });

  it("should not allow non owner to set contract fee", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newContractFees = "1000000";
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set contractFee by non owner
        return YieldContractInstance.setParamType(0, newContractFees, {
          from: nonOwner,
        });
      })
      .catch(function (error) {
        // Print error
        console.log(error.message);
        assert(true);
      });
  });

  it("should allow owner to set contract fee and return it properly", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newContractFee = "1000000";
    let owner = accounts[0];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set contract fee by owner
        return YieldContractInstance.setParamType(0,newContractFee, {from: owner});
      })
      .then(function (result) {
        // Get min penalty details
        return YieldContractInstance.contractFee.call( {
          from: owner
        });
      })
      .then(function (result) {
        // Assert
        assert.deepEqual(
          result.toString(),
          newContractFee,
          "New contract fee not returned properly"
        );
      });
  });
  
  it("should get MXX token address", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to get MXX address
      return YieldContractInstance.mxxAddress.call({ from: nonOwner });
    }).then(function(result){

      // Assert
      assert.deepEqual(result,multiplierInstance.address,"Yield contract fee not returned properly");
    });
  });
  
  it("should get total allocated MXX for yield contracts", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let expectedResult = "100000000000000000"; 
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to get total allocated MXX
      return YieldContractInstance.totalAllocatedMxx.call({from: nonOwner});
    }).then(function(result){

      // Assert
      assert.deepEqual(result.toString(),expectedResult,"Total allocated MXX not returned properly");
    });
  });
  
  it("should get MXX minted from yield contracts successfully", function () {
    
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let expectedResult = "0"; 
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
    .then(function(instance){

      multiplierInstance = instance;
    
    // Deploy yield contract
    return YieldContract.deployed(multiplierInstance.address,"10000000000000000")
    }).then(function(instance){

      YieldContractInstance = instance;

      // Attempt to get MXX minted from yield contracts
      return YieldContractInstance.mxxMintedFromContract.call({from: nonOwner});
    }).then(function(result){

      // Assert
      assert.deepEqual(result.toString(),expectedResult,"MXX minted from yield contracts not returned properly");
    });
  });

  it("should not allow non owner to set minimum penalty", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newminEarlyRedeemFee = "1000000";
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set min penalty tenure by non owner
        return YieldContractInstance.setParamType(1,newminEarlyRedeemFee, {from: nonOwner});
      })
      .catch(function (error) {
        // Print error
        console.log(error.message);
        assert(true);
      });
  });

  it("should allow owner to set min penalty and return it properly", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newminEarlyRedeemFee = "1000000";
    let owner = accounts[0];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set minimum penalty by owner
        return YieldContractInstance.setParamType(1,newminEarlyRedeemFee, {from: owner});
      })
      .then(function (result) {
        // Get min penalty details
        return YieldContractInstance.minEarlyRedeemFee.call( {
          from: owner
        });
      })
      .then(function (result) {
        // Assert
        assert.deepEqual(
          result.toString(),
          newminEarlyRedeemFee,
          "New min penalty not returned properly"
        );
      });
  });

  it("should not allow non owner to set maximum penalty", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newmaxEarlyRedeemFee = "500000000";
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set max penalty tenure by non owner
        return YieldContractInstance.setParamType(2,newmaxEarlyRedeemFee, {
          from: nonOwner,
        });
      })
      .catch(function (error) {
        // Print error
        console.log(error.message);
        assert(true);
      });
  });

  it("should allow owner to set max penalty and return it properly", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newmaxEarlyRedeemFee = "500000000";
    let owner = accounts[0];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set max penalty by owner
        return YieldContractInstance.setParamType(2,newmaxEarlyRedeemFee, {
          from: owner,
        });
      })
      .then(function (result) {
        // Get max penalty details
        return YieldContractInstance.maxEarlyRedeemFee.call({
          from: owner,
        });
      })
      .then(function (result) {
        // Assert
        assert.deepEqual(
          result.toString(),
          newmaxEarlyRedeemFee,
          "New max penalty not returned properly"
        );
      });
  });

  it("should not allow non owner to set total allocated mxx", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newAllocatedMxx = "50000000000";
    let nonOwner = accounts[1];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set total allocated mxx by non owner
        return YieldContractInstance.setParamType(3, newAllocatedMxx, {
          from: nonOwner,
        });
      })
      .catch(function (error) {
        // Print error
        console.log(error.message);
        assert(true);
      });
  });

  it("should allow owner to set total allocated MXX and return it properly", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newAllocatedMxx = "50000000000";
    let owner = accounts[0];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set allocated MXX by owner
        return YieldContractInstance.setParamType(3, newAllocatedMxx, {
          from: owner,
        });
      })
      .then(function (result) {
        // Get max penalty details
        return YieldContractInstance.totalAllocatedMxx.call({
          from: owner,
        });
      })
      .then(function (result) {
        // Assert
        assert.deepEqual(
          result.toString(),
          newAllocatedMxx,
          "New allocated mxx not returned properly"
        );
      });
  });

  it("should not allow owner to set total allocated MXX within incorrect enum value", function () {
    // Define variables
    let multiplierInstance;
    let YieldContractInstance;
    let newAllocatedMxx = "50000000000";
    let owner = accounts[0];

    // Deploy multiplier contract
    return Multiplier.deployed()
      .then(function (instance) {
        multiplierInstance = instance;

        // Deploy yield contract
        return YieldContract.deployed(
          multiplierInstance.address,
          "10000000000000000"
        );
      })
      .then(function (instance) {
        YieldContractInstance = instance;

        // Attempt to set allocated MXX by owner
        return YieldContractInstance.setParamType(8, newAllocatedMxx, {
          from: owner,
        });
      })
      .catch(function (error) {
        
        // Print error
        console.log(error.message);
        assert(true);
      });
    });
});

