// SPDX-License-Identifier: CC-BY-NC-ND-4.0

pragma solidity ^0.6.0;

// Importing libraries
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Tokens/Multiplier.sol";


/**
 * @title Yield Contract
 * @notice Contract to create yield contracts for users
 */

/**
 * TO NOTE
 * @notice Store collateral and provide interest MXX or burn MXX
 * @notice Interest (contractFee, penaltyFee etc) is always represented 10 power 6 times the actual value
 * @notice Note that only 4 decimal precision is allowed for interest
 * @notice If interest is 5%, then value to input is 0.05 * 10 pow 6 = 5000
 * @notice mFactor or mintFactor is represented 10 power 18 times the actual value.
 * @notice If value of 1 ETH is 380 USD, then mFactor of ETH is (380 * (10 power 18))
 * @notice Collateral should always be in its lowest denomination (based on the coin or Token)
 * @notice If collateral is 6 USDT, then value is 6 * (10 power 6) as USDT supports 6 decimals
 * @notice startTime and endTime are represented in Unix time
 * @notice tenure for contract is represented in days (90, 180, 270) etc
 * @notice mxxToBeMinted or mxxToBeMinted is always in its lowest denomination (8 decimals)
 * @notice For e.g if mxxToBeMinted = 6 MXX, then actual value is 6 * (10 power 8)
 */

contract YieldContract is Ownable, ReentrancyGuard {

  // Using SafeMath Library to prevent integer overflow
  using SafeMath for uint256;

  // Using Address library for ERC20 contract checks
  using Address for address;

  /**
   * DEFINING VARIABLES
   */

  /**
   * @dev - Array to store valid ERC20 addresses 
   */  
  address[] public validERC20;

  /**
   * @dev - A struct to store ERC20 details
   * @notice symbol - The symbol/ ticker symbol of ERC20 contract
   * @notice isValid - Boolean variable indicating if the ERC20 is valid to be used for yield contracts
   * @notice noContracts - Integer indicating the number of contracts associated with it
   * @notice mFactor - Value of a coin/token in USD * 10 power 18
   */  
  struct ERC20Details {
    string symbol;
    bool isValid;
    uint64 noContracts;
    uint256 mFactor;
  }

  /**
   * @dev - A mapping to map ERC20 addresses to its details
   */ 
  mapping(address => ERC20Details) public ERC20Map;

  /**
   * @dev - Array to store user created yield contract IDs 
   */  
  bytes32[] public allContracts;

  /**
   * @dev - A enum to store yield contract status
   */ 
  enum Status { inactive, active, openMarket, claimed}

  /**
   * @dev - A enum to switch set value case
   */    
  enum paramType { contractFee, minEarlyRedeemFee, maxEarlyRedeemFee, totalAllocatedMxx}

  /**
   * @dev - A struct to store yield contract details
   * @notice contractOwner - The owner of the yield contract
   * @notice tokenAddress - ERC20 contract address (if ETH then address(0))
   * @notice startTime - Start time of the yield contract (in unix timestamp)
   * @notice endTime - End time of the yield contract (in unix timestamp)
   * @notice tenure - The agreement tenure in days   
   * @notice contractStatus - The status of a contract (can be inactive/active/openMarket/Claimed)
   * @notice collateral - Value of collateral (multiplied by 10 power 18 to handle decimals)
   * @notice mxxToBeMinted - The final MXX token value to be returned to the contract owner
   * @notice interest - APY or Annual Percentage Yield (returned from tenureApyMap)
   */  
  struct contractDetails {
    address contractOwner;
    uint48 startTime;
    uint48 endTime;
    address tokenAddress;    
    uint16 tenure;
    uint64 interest;
    uint8 contractStatus; 
    uint256 collateral;
    uint256 mxxToBeMinted;
  }

  /**
   * @dev - A mapping to map contract IDs to their details
   */ 
  mapping(bytes32 => contractDetails) public contractMap;

  /**
   * @dev - A mapping to map tenure in days to apy (Annual Percentage Yield aka interest rate)
   * Percent rate is multiplied by 10 power 6. (For e.g. if 5% then value is 0.05 * 10 power 6)
   */ 
  mapping(uint16 => uint64) public tenureApyMap;

  /**
   * @dev - Variable to store contract fee
   * If 10% then value is 0.1 * 10 power 6
   */ 
  uint64 public contractFee;

  /**
   * @dev - Variable to store MXX ERC20 token address
   */ 
  address public mxxAddress;

  /**
   * @dev - Address where MXX will be sent to burn
   */ 
  address public burnAddress;

  /**
   * @dev - Variable to store total allocated MXX for yield contracts
   */ 
  uint256 public totalAllocatedMxx;

  /**
   * @dev - Variable to total MXX minted from yield contracts
   */ 
  uint256 public mxxMintedFromContract;

  /**
   * @dev - Variables to store % of penalty / redeem fee fees
   * If min penalty / redeem fee is 5% then value is 0.05 * 10 power 6
   * If max penalty / redeem fee is 50% then value is 0.5 * 10 power 6
   */ 
  uint64 public minEarlyRedeemFee;
  uint64 public maxEarlyRedeemFee;

  /**
   * DEFINING EVENTS
   */

  /**
   * @dev - An event to be emitted when a contract is created/updated
   * @notice contractOwner - The owner of the yield contract
   * @notice tokenAddress - ERC20 contract address (if ETH then address(0))
   * @notice collateral - Value of collateral (multiplied by 10 power 18 to handle decimals)
   * @notice startTime - Start time of the yield contract (in unix timestamp)
   * @notice endTime - End time of the yield contract (in unix timestamp)
   * @notice interest - APY or Annual Percentage Yield (returned from tenureApyMap)
   * @notice tenure - The agreement tenure in days
   * @notice mxxToBeMinted - The final MXX token value to be returned to the contract owner
   * @notice contractStatus - The status of a contract (can be inactive/active/openMarket/Claimed)
   */ 

/*
  event yieldContractStatus(
  address contractOwner, 
  address tokenAddress, 
  uint256 collateral, 
  uint48 startTime,
  uint48 endTime,  
  uint16 tenure, 
  uint64 interest,
  uint256 mxxToBeMinted, 
  string contractStatus);
*/

  /**
   * CONSTRUCTOR FUNCTION
   */

  constructor(address _mxxAddress, uint256 _mxxmFactor) public Ownable() {

    // Setting default variables
    tenureApyMap[90] = uint64(SafeMath.mul(50, 10 ** 4));
    tenureApyMap[180] = uint64(SafeMath.mul(100, 10 ** 4));
    tenureApyMap[270] = uint64(SafeMath.mul(300, 10 ** 4));
    contractFee = uint64(SafeMath.mul(10, 10 ** 4));
    totalAllocatedMxx = SafeMath.mul(1000000000, 10 ** 8); // 1 billion initial Mxx allocated //
    minEarlyRedeemFee = uint64(SafeMath.mul(5, 10 ** 4));
    maxEarlyRedeemFee = uint64(SafeMath.mul(50, 10 ** 4));
    mxxMintedFromContract = 0;
    burnAddress = 0x19B292c1a84379Aab41564283e7f75bF20e45f91; // Official Burn Address //

    // Setting MXX address
    mxxAddress = _mxxAddress;
    addValidERC20(_mxxAddress,_mxxmFactor);

  }

  /**
   * INTERNAL FUNCTIONS
   */

  /**
   * @dev This function will check the array for an element and retun the index
   * @param _inputAddress - Address for which the index has to be found
   * @param _inputAddressList - The address list to be checked
   * @return index - Index element indicating the position of the inputAddress inside the array
   * Access Control: This contract or derived contract
   */
  
  function getIndex(address _inputAddress, address[] memory _inputAddressList) internal pure returns(uint32 index) {

    // Enter loop
    for(uint32 i = 0; i < _inputAddressList.length; i++) {

      // If value matches, return index
      if(_inputAddress == _inputAddressList[i]) {
        index = i;
        return(index);
      }
    }

    // If no value matches, revert
    revert();
  }

  /**
   * GENERAL FUNCTIONS
   */ 

  /**
   * @dev This function will set interest rate for the tenure in days
   * @param _tenure - Tenure of the agreement in days
   * @param _interestRate - Interest rate in 10 power 6 (If 5%, then value is 0.05 * 10 power 6)
   * @return - Boolean status - True indicating successful completion
   * Access Control: Only Owner
   */
  
  function setInterest(uint16 _tenure, uint64 _interestRate) public onlyOwner() returns(bool ) {
    tenureApyMap[_tenure] = _interestRate;
    return true;
  }

  /**
   * @dev This function will set value based on paramType (contract fee, mxx penalty fee, max penalty fee, total allocated)
   * @param _parameter - Enum value indicating paramType (0,1,2,3)
   * @param _value - Value to be set
   * @return - Boolean status - True indicating successful completion
   * Access Control: Only Owner
   */

  function setParamType(paramType _parameter, uint256 _value) public onlyOwner() returns(bool ) {
    if(_parameter == paramType.contractFee) {
      contractFee = uint64(_value);
    } else if(_parameter == paramType.minEarlyRedeemFee) {
      minEarlyRedeemFee = uint64(_value);
    } else if(_parameter == paramType.maxEarlyRedeemFee) {
      maxEarlyRedeemFee = uint64(_value);
    } else if(_parameter == paramType.totalAllocatedMxx) {
      totalAllocatedMxx = _value;
    }
  }

  /**
   * VALID ERC20 ADDRESS FUNCTIONS
   */

  /**
   * @dev Adds a valid ERC20 address into the contract
   * @param _ERC20Address - Address of the ERC20 contract
   * @param _mFactor - Mint Factor of the token (value of 1 token in USD * 10 power 18)
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function addValidERC20(address _ERC20Address, uint256 _mFactor) public onlyOwner() returns(bool ) {

    // Check for existing contracts and validity. If condition fails, revert
    require(_ERC20Address == address(0) || Address.isContract(_ERC20Address),"Not contract address");
    require(ERC20Map[_ERC20Address].noContracts == 0, "Token has existing contracts");
    require(!ERC20Map[_ERC20Address].isValid, "Token already available");

    // Add token details and return true
    // If _ERC20Address = address(0) then it is ETH else ERC20
    if(_ERC20Address == address(0)) {

      // Add ETH
      ERC20Map[_ERC20Address] = ERC20Details('ETH', true, 0, _mFactor);

    } else {

      // Add ERC20
      ERC20Map[_ERC20Address] = ERC20Details(ERC20(_ERC20Address).symbol(), true, 0, _mFactor);

    }
    validERC20.push(_ERC20Address);
    return true;
  }

  /**
   * @dev Adds a list of valid ERC20 addresses into the contract
   * @param _ERC20AddressList - List of addresses of the ERC20 contract
   * @param _mFactorList - List of mint factors of the token
   * @return - Boolean status - True indicating successful completion
   * @notice - The length of _ERC20AddressList and _mFactorList must be the same
   * @notice - Access control: Only Owner
   */
  function addValidERC20List(address[] memory _ERC20AddressList, uint256[] memory _mFactorList) public onlyOwner() returns(bool ) {

    // Check if the length of 2 input arrays are the same else throw
    require(_ERC20AddressList.length == _mFactorList.length, "Inconsistent Inputs");

    // Enter loop and token details
    for(uint32 i = 0; i < _ERC20AddressList.length; i++) {
      addValidERC20(_ERC20AddressList[i],_mFactorList[i]);
    }
    return true;
  }

  /**
   * @dev Removes a valid ERC20 addresses from the contract
   * @param _ERC20Address - Address of the ERC20 contract to be removed
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function removeValidERC20(address _ERC20Address) public onlyOwner() returns(bool ) {

    // Check if Valid ERC20 not equals mxxAddress
    require(_ERC20Address != mxxAddress,"Cannot remove MXX");

    // Check if _ERC20Address has existing yield contracts
    require(ERC20Map[_ERC20Address].noContracts == 0, "Token has existing contracts");

    // Get array index
    uint256 index = getIndex(_ERC20Address, validERC20);

    // Get last valid ERC20 address in the array
    address lastERC20Address = validERC20[validERC20.length - 1];

    // Assign last address to the index position
    validERC20[index] = lastERC20Address;

    // Delete last address from the array
    delete validERC20[validERC20.length - 1];
    validERC20.pop();

    // Delete ERC20 details for the input address
    delete ERC20Map[_ERC20Address];
    return true;
  }

  /**
   * @dev Delists ERC20 address to prevent adding new yield contracts with this ERC20 collateral
   * @param _ERC20Address - Address of the ERC20 contract
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function delistValidERC20(address _ERC20Address) public onlyOwner() returns(bool ) {

    // Check if ERC20 already removed or delisted. If condition fails, revert
    require(ERC20Map[_ERC20Address].isValid, "Token already delisted/removed");

    // Delist valid ERC20
    ERC20Map[_ERC20Address].isValid = false;
    return true;
  }

  /**
   * @dev Undelists ERC20 address to resume adding new yield contracts with this ERC20 collateral
   * @param _ERC20Address - Address of the ERC20 contract
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function undelistERC20(address _ERC20Address) public onlyOwner() returns(bool ) {

    // Check if address a contract address and if delisted. If condition fails, revert
    require(_ERC20Address == address(0) || Address.isContract(_ERC20Address),"Not contract address");
    require(!ERC20Map[_ERC20Address].isValid, "Token already enrolled");

    // Delist valid ERC20
    ERC20Map[_ERC20Address].isValid = true;
    return true;
  }

  /**
   * @dev Updates the mint factor of a coin/token
   * @param _ERC20Address - Address of the ERC20 contract or ETH address (address(0))
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function updateMFactor(address _ERC20Address, uint256 _mFactor) public onlyOwner() returns(bool ) {

    // Check if address a contract address and if in the valid ERC20 array. If condition fails, revert
    require(_ERC20Address == address(0) || Address.isContract(_ERC20Address),"Not contract address");

    // Update mint factor
    ERC20Map[_ERC20Address].mFactor = _mFactor;
    return true;
  }

  /**
   * @dev Updates the mint factor for list of coin(s)/token(s)
   * @param _ERC20AddressList - List of ERC20 addresses
   * @param _mFactorList - List of mint factors for ERC20 addresses
   * @return - Boolean status - True indicating successful completion
   * @notice - Length of the 2 input arrays must be the same
   * @notice - Access control: Only Owner
   */
  function updateMFactorList(address[] memory _ERC20AddressList, uint256[] memory _mFactorList) public onlyOwner() returns(bool ) {

    // Length of the 2 input arrays must be the same. If condition fails, revert
    require(_ERC20AddressList.length == _mFactorList.length,"Inconsistent Inputs");

    // Enter the loop, update and return true
    for(uint32 i = 0; i < _ERC20AddressList.length; i++) {
      updateMFactor(_ERC20AddressList[i],_mFactorList[i]);
    }
    return true;
  }

  /**
   * @dev Returns number of valid Tokens/Coins supported
   * @return - Number of valid tokens/coins
   * @notice - Access control: Public
   */
  function getNoOfValidTokens() public view returns(uint256 ) {
    return(validERC20.length);
    
  }

  /**
   * @dev Returns subset list of valid ERC20 contracts
   * @param _start - Start index to search in the list
   * @param _end - End index to search in the list
   * @return - subsetValidERC20 - List of valid ERC20 addresses subset
   * @notice - Access control: Public
   */
  function getSubsetValidERC20(uint32 _start, uint32 _end) public view returns(address[] memory ) {

    // Check conditions else fail
    require(_start <= _end, "Invalid limits");

    // If _end higher than length of array, set end index to last element of the array
    if(_end >= validERC20.length) {
      _end = uint32(SafeMath.sub(validERC20.length,1));
    }

    // Define return array
    uint256 noOfElements = SafeMath.add(SafeMath.sub(_end,_start),1);
    address[] memory subsetValidERC20 = new address[](noOfElements);

    // Loop in and add elements from validERC20 array
    for(uint32 i = _start; i <= _end; i++) {
      subsetValidERC20[i - _start] = validERC20[i];
    }
    return(subsetValidERC20);
  }

  /**
   * YIELD CONTRACT FUNCTIONS
   */

  /**
   * @dev Creates a yield contract
   * @param _ERC20Address - The address of the ERC20 token (address(0) if ETH)
   * @param _collateral - The collateral value of the ERC20 token or ETH
   * @param _tenure - The number of days of the agreement
   * @notice - Collateral to be input - Actual value * (10 power decimals)
   * @notice - For e.g If collateral is 5 USDT (Tether) and decimal is 6, then _collateral is (5 * (10 power 6))
   * Non Reentrant modifier is used to prevent re-entrancy attack
   * @notice - Access control: External
   */
  
  function createYieldContract(address _ERC20Address, uint256 _collateral, uint16 _tenure) external nonReentrant() payable {

    // Check if token/ETH is approved to create contracts
    require(ERC20Map[_ERC20Address].isValid, "Token/Coin not approved");

    // Create contractId and check if status inactive (enum state 0)
    bytes32 contractId = keccak256(abi.encodePacked(msg.sender, _ERC20Address, now, allContracts.length));
    require(contractMap[contractId].contractStatus == uint8(Status.inactive), "Contract already exists");

    // Check if APY (interest rate is not zero for the tenure)
    require(tenureApyMap[_tenure] != 0, "No interest rate is set");

    // Get decimal value for collaterals
    uint256 collateralDecimals;
    if(_ERC20Address == address(0)) {

      // In case of ETH, check to ensure if collateral value match ETH sent
      require(msg.value == _collateral && msg.value > 0,"Incorrect funds");

      // ETH decimals is 18
      collateralDecimals = 10 ** 18;     

    } else {

      // In case of non ETH, check to ensure if msg.value is 0
      require(msg.value == 0,"Incorrect funds");
      require(_collateral != 0,"Collateral is 0");

      collateralDecimals = 10 ** uint256(ERC20(_ERC20Address).decimals());

      // Transfer collateral
      ERC20(_ERC20Address).transferFrom(msg.sender, address(this),_collateral);
    }

    // Calculate MXX to be Minted
    uint256 numerator = SafeMath.mul(SafeMath.mul(SafeMath.mul(SafeMath.mul(_collateral,ERC20Map[_ERC20Address].mFactor),tenureApyMap[_tenure]),10 ** uint256(ERC20(mxxAddress).decimals())),_tenure);
    uint256 denominator = SafeMath.mul(SafeMath.mul(SafeMath.mul(collateralDecimals, ERC20Map[mxxAddress].mFactor),SafeMath.mul(100,10 ** 4)),365);
    uint256 valueToBeMinted = SafeMath.div(numerator,denominator);

    // Check the MXX to be minted will result in total MXX allocated for creating yield contracts
    require(totalAllocatedMxx >= SafeMath.add(mxxMintedFromContract,valueToBeMinted), "Total allocated MXX exceeded");

    // Update total MXX minted from yield contracts
    mxxMintedFromContract = SafeMath.add(mxxMintedFromContract , valueToBeMinted);

    // Calculate MXX to be burnt 
    numerator = SafeMath.mul(valueToBeMinted,contractFee);
    denominator = SafeMath.mul(100,10 ** 4);  
    uint256 valueToBeBurnt = SafeMath.div(numerator,denominator);

    // Send valueToBeBurnt to contract fee destination
    Multiplier(mxxAddress).transferFrom(msg.sender, burnAddress, valueToBeBurnt);

    // Create contract
    contractMap[contractId] = contractDetails(msg.sender,uint48(now),uint48(SafeMath.add(now, SafeMath.mul(_tenure, 1 days))),_ERC20Address,_tenure,tenureApyMap[_tenure],uint8(Status.active),_collateral,valueToBeMinted);

    // Push to all contracts and user contracts
    allContracts.push(contractId);

    // Increase number of contracts ERC20 details
    ERC20Map[_ERC20Address].noContracts += 1;
  }

  /**
   * @dev Early Redeem a yield contract
   * @param _contractId - The Id of the contract
   * Non Reentrant modifier is used to prevent re-entrancy attack
   * @notice - Access control: External
   */
  
  function earlyRedeemContract(bytes32 _contractId) external nonReentrant() {

    // Check if contract is active
    require(contractMap[_contractId].contractStatus == uint8(Status.active),"Contract is not active");

    // Check if redeemer is the owner
    require(contractMap[_contractId].contractOwner == msg.sender,"Redeemer is not owner");

    // Check if current time is less than end time but greater than start time
    require(now > contractMap[_contractId].startTime && now < contractMap[_contractId].endTime, "Contract is beyond its end time");

    // Calculate mxxMintedTillDate
    uint256 numerator = SafeMath.mul(SafeMath.sub(now, contractMap[_contractId].startTime),contractMap[_contractId].mxxToBeMinted);
    uint256 denominator = SafeMath.sub(contractMap[_contractId].endTime, contractMap[_contractId].startTime);
    uint256 mxxMintedTillDate = SafeMath.div(numerator,denominator);

    // Calculate penaltyPercent
    numerator = SafeMath.mul(SafeMath.sub(maxEarlyRedeemFee, minEarlyRedeemFee),SafeMath.sub(now, contractMap[_contractId].startTime));
    denominator = SafeMath.sub(contractMap[_contractId].endTime, contractMap[_contractId].startTime);
    uint256 penaltyPercent = SafeMath.sub(maxEarlyRedeemFee,SafeMath.div(numerator,denominator));

    // Calculate penaltyMXXToBurn
    numerator = SafeMath.mul(penaltyPercent,mxxMintedTillDate);
    denominator = SafeMath.mul(100,10 ** 4);
    uint256 penaltyMXXToBurn = SafeMath.div(numerator,denominator);

    // Calculate mxxToBeSent
    uint256 mxxToBeSent = SafeMath.sub(mxxMintedTillDate,penaltyMXXToBurn);

    // Return collateral
    if(contractMap[_contractId].tokenAddress == address(0)) {

      // Send back ETH
      (bool success, ) = contractMap[_contractId].contractOwner.call{value: contractMap[_contractId].collateral}("Collateral Return");
      require(success, "Transfer failed");
    } else {
      // Send back ERC20 collateral
      ERC20(contractMap[_contractId].tokenAddress).transfer(contractMap[_contractId].contractOwner, contractMap[_contractId].collateral);      
    }

    // Return MXX
    Multiplier(mxxAddress).transfer(contractMap[_contractId].contractOwner, mxxToBeSent);

    // Burn penalty fee
    Multiplier(mxxAddress).transfer(burnAddress, penaltyMXXToBurn);

    // Updating contract 
    contractMap[_contractId].startTime = uint48(now);
    contractMap[_contractId].mxxToBeMinted = SafeMath.sub(contractMap[_contractId].mxxToBeMinted,mxxMintedTillDate);
    contractMap[_contractId].contractOwner = address(0);
    contractMap[_contractId].contractStatus = uint8(Status.openMarket);  
  }

  /**
   * @dev Acquire a yield contract in the open market
   * @param _contractId - The Id of the contract
   * Non Reentrant modifier is used to prevent re-entrancy attack
   * @notice - Access control: External
   */
  
  function acquireYieldContract(bytes32 _contractId) external nonReentrant() payable {

    // Check if contract is open
    require(contractMap[_contractId].contractStatus == uint8(Status.openMarket),"Contract not in open market");

    // Check if owner is address(0)
    require(contractMap[_contractId].contractOwner == address(0),"Contract already owned");

    // Get collateral in case of ERC20 tokens, for ETH it is already received via msg.value
    if(contractMap[_contractId].tokenAddress != address(0)) {

      // In case of ERC20, ensure no ETH is sent
      require(msg.value == 0, "ETH should not be sent");
      ERC20(contractMap[_contractId].tokenAddress).transferFrom(msg.sender, address(this),contractMap[_contractId].collateral);
    } else {

      // In case of ETH check if money received equals the collateral else revert
      require(msg.value == contractMap[_contractId].collateral, "Incorrect funds");
    }

    // Updating contract 
    contractMap[_contractId].contractOwner = msg.sender;
    contractMap[_contractId].contractStatus = uint8(Status.active);    
  }

  /**
   * @dev Claim a yield contract in the active market
   * @param _contractId - The Id of the contract
   * Non Reentrant modifier is used to prevent re-entrancy attack
   * @notice - Access control: External
   */
  
  function claimYieldContract(bytes32 _contractId) external nonReentrant() {

    // Check if contract is active
    require(contractMap[_contractId].contractStatus == uint8(Status.active),"Contract is not active");

    // Check if owner and msg.sender are the same
    require(contractMap[_contractId].contractOwner == msg.sender,"Contract owned by someone else");

    // Check if current time is greater than contract end time
    require(now >= contractMap[_contractId].endTime, "Too early to claim");

    // Return collateral
    if(contractMap[_contractId].tokenAddress == address(0)) {

      // Send back ETH
      (bool success, ) = contractMap[_contractId].contractOwner.call{value: contractMap[_contractId].collateral}("Collateral Return");
      require(success, "Transfer failed");
    } else {
      // Send back ERC20 collateral
      ERC20(contractMap[_contractId].tokenAddress).transfer(contractMap[_contractId].contractOwner, contractMap[_contractId].collateral);      
    }

    // Return minted MXX
    Multiplier(mxxAddress).transfer(contractMap[_contractId].contractOwner, contractMap[_contractId].mxxToBeMinted);


    // Updating contract 
    contractMap[_contractId].contractStatus = uint8(Status.claimed);

    // Reduce no of contracts in ERC20 details
    ERC20Map[contractMap[_contractId].tokenAddress].noContracts -= 1;    
  }

  /**
   * @dev This function will subset of yield contract
   * @param _start - Start of the list
   * @param _end - End of the list
   * @return - List of subset yield contract
   * Access Control: Public
   */
  
  function getSubsetYieldContracts(uint32 _start, uint32 _end) public view returns(bytes32[] memory ) {

    // Check conditions else fail
    require(_start <= _end, "Invalid limits");

    // If _end higher than length of array, set end index to last element of the array
    if(_end >= allContracts.length) {
      _end = uint32(SafeMath.sub(allContracts.length,1));
    }

    // Define return array
    uint256 noOfElements = SafeMath.add(SafeMath.sub(_end,_start),1);
    bytes32[] memory subsetYieldContracts = new bytes32[](noOfElements);

    // Loop in and add elements from allContracts array
    for(uint32 i = _start; i <= _end; i++) {
      subsetYieldContracts[i - _start] = allContracts[i];
    }

    return subsetYieldContracts;

  } 

  /**
   * @dev This function will withdraw MXX back to the owner
   * @param _amount - Amount of MXX need to withdraw
   * @return - Boolean status indicating successful completion
   * Access Control: Only Owner
   */
  
  function withdrawMXX(uint256 _amount) public onlyOwner() nonReentrant() returns(bool ) {
    Multiplier(mxxAddress).transfer(msg.sender, _amount);
    return true;
  }
}