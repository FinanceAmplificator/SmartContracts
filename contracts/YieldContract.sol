// SPDX-License-Identifier: CC-BY-NC-ND-4.0

pragma solidity 0.6.2;

// Importing libraries
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


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

  // Using SafeERC20 for ERC20
  using SafeERC20 for ERC20;

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
  address[] public ERC20List;

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
  enum Status { inactive, active, openMarket, claimed, destroyed}

  /**
   * @dev - A enum to switch set value case
   */    
  enum ParamType { contractFee, minEarlyRedeemFee, maxEarlyRedeemFee, totalAllocatedMxx}

  /**
   * @dev - A struct to store yield contract details
   * @notice contractOwner - The owner of the yield contract
   * @notice tokenAddress - ERC20 contract address (if ETH then ZERO_ADDRESS)
   * @notice startTime - Start time of the yield contract (in unix timestamp)
   * @notice endTime - End time of the yield contract (in unix timestamp)
   * @notice tenure - The agreement tenure in days   
   * @notice contractStatus - The status of a contract (can be inactive/active/openMarket/Claimed/Destroyed)
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
    Status contractStatus; 
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
  mapping(uint256 => uint64) public tenureApyMap;

  /**
   * @dev - Variable to store contract fee
   * If 10% then value is 0.1 * 10 power 6
   */ 
  uint64 public contractFee;

  /**
   * @dev - Variable to store MXX ERC20 token address
   */ 
  address public constant MXX_ADDRESS = 0x8a6f3BF52A26a21531514E23016eEAe8Ba7e7018; // Official MXX Token address //

  /**
   * @dev - Address where MXX will be sent to burn
   */ 
  address public constant BURN_ADDRESS = 0x19B292c1a84379Aab41564283e7f75bF20e45f91; // Official Burn Address //

  /**
   * @dev - Variable to store ETH address
   */ 
  address internal constant ZERO_ADDRESS = address(0);

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
   * CONSTRUCTOR FUNCTION
   */

  constructor(uint256 _mxxmFactor) public Ownable() {

    // Setting default variables
    tenureApyMap[90] = 2*(10 ** 6);
    tenureApyMap[180] = 4*(10 ** 6);
    tenureApyMap[270] = 10*(10 ** 6);
    contractFee = 0.08*(10 ** 6);
    totalAllocatedMxx = 1000000000*(10 ** 8); // 1 billion initial Mxx allocated //
    minEarlyRedeemFee = 0.05*(10 ** 6);
    maxEarlyRedeemFee = 0.5*(10 ** 6);

    addERC20(MXX_ADDRESS,_mxxmFactor);

  }

  /**
   * DEFINE MODIFIER
   */

  /**
   * @dev Throws if address is a user address (except ZERO_ADDRESS)
   * @param _ERC20Address - Address to be checked
   */

  modifier onlyERC20OrETH(address _ERC20Address) {
    require(_ERC20Address == ZERO_ADDRESS || Address.isContract(_ERC20Address),"Not contract address");
    _;
  }

  /**
   * @dev Throws if address in not in ERC20 list (check for mFactor and symbol done here)
   * @param _ERC20Address - Address to be checked
   */

  modifier inERC20List(address _ERC20Address) {
    require(ERC20Map[_ERC20Address].mFactor > 0 || bytes(ERC20Map[_ERC20Address].symbol).length > 0,"Not in ERC20 list");
    _;
  }

  /**
   * INTERNAL FUNCTIONS
   */

  /**
   * @dev This function will check the array for an element and retun the index
   * @param _inputAddress - Address for which the index has to be found
   * @param _inputAddressList - The address list to be checked
   * @return index - Index element indicating the position of the inputAddress inside the array
   * @return isFound - Boolean indicating if the element is present in the array or not
   * Access Control: This contract or derived contract
   */
  
  function getIndex(address _inputAddress, address[] memory _inputAddressList) internal pure returns(uint256 index, bool isFound) {

    // Enter loop
    for(uint256 i = 0; i < _inputAddressList.length; i++) {

      // If value matches, return index
      if(_inputAddress == _inputAddressList[i]) {
        return(i,true);
      }
    }

    // If no value matches, return false
    return(0,false);
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
  
  function setInterest(uint256 _tenure, uint64 _interestRate) public onlyOwner() returns(bool ) {
    tenureApyMap[_tenure] = _interestRate;
    return true;
  }

  /**
   * @dev This function will set value based on ParamType (contract fee, mxx penalty fee, max penalty fee, total allocated)
   * @param _parameter - Enum value indicating ParamType (0,1,2,3)
   * @param _value - Value to be set
   * @return - Boolean status - True indicating successful completion
   * Access Control: Only Owner
   */

  function setParamType(ParamType _parameter, uint256 _value) public onlyOwner() returns(bool ) {
    if(_parameter == ParamType.contractFee) {
      contractFee = uint64(_value);
    } else if(_parameter == ParamType.minEarlyRedeemFee) {
      require(uint64(_value) <= maxEarlyRedeemFee,"Greater than max redeem fee");
      minEarlyRedeemFee = uint64(_value);
    } else if(_parameter == ParamType.maxEarlyRedeemFee) {
      require(uint64(_value) >= minEarlyRedeemFee,"Less than min redeem fee");
      maxEarlyRedeemFee = uint64(_value);
    } else if(_parameter == ParamType.totalAllocatedMxx) {
      require(_value >= mxxMintedFromContract,"Less than total mxx minted");
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
  function addERC20(address _ERC20Address, uint256 _mFactor) public onlyOwner() onlyERC20OrETH(_ERC20Address) returns(bool ) {

    // Check for existing contracts and validity. If condition fails, revert
    require(ERC20Map[_ERC20Address].noContracts == 0, "Token has existing contracts");
    require(!ERC20Map[_ERC20Address].isValid, "Token already available");

    // Add token details and return true
    // If _ERC20Address = ZERO_ADDRESS then it is ETH else ERC20
    ERC20Map[_ERC20Address] = ERC20Details((_ERC20Address == ZERO_ADDRESS) ? "ETH": ERC20(_ERC20Address).symbol(),true,0, _mFactor);
    ERC20List.push(_ERC20Address);
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
  function addERC20List(address[] memory _ERC20AddressList, uint256[] memory _mFactorList) public onlyOwner() returns(bool ) {

    // Check if the length of 2 input arrays are the same else throw
    require(_ERC20AddressList.length == _mFactorList.length, "Inconsistent Inputs");

    // Enter loop and token details
    for(uint256 i = 0; i < _ERC20AddressList.length; i++) {
      addERC20(_ERC20AddressList[i],_mFactorList[i]);
    }
    return true;
  }

  /**
   * @dev Removes a valid ERC20 addresses from the contract
   * @param _ERC20Address - Address of the ERC20 contract to be removed
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function removeERC20(address _ERC20Address) public onlyOwner() returns(bool ) {

    // Check if Valid ERC20 not equals MXX_ADDRESS
    require(_ERC20Address != MXX_ADDRESS,"Cannot remove MXX");

    // Check if _ERC20Address has existing yield contracts
    require(ERC20Map[_ERC20Address].noContracts == 0, "Token has existing contracts");

    // Get array index and isFound flag
    uint256 index;
    bool isFound;    
    (index,isFound) = getIndex(_ERC20Address, ERC20List);

    // Require address to be in list
    require(isFound,"Address not found");

    // Get last valid ERC20 address in the array
    address lastERC20Address = ERC20List[ERC20List.length - 1];

    // Assign last address to the index position
    ERC20List[index] = lastERC20Address;

    // Delete last address from the array
    ERC20List.pop();

    // Delete ERC20 details for the input address
    delete ERC20Map[_ERC20Address];
    return true;
  }

  /**
   * @dev Enlists/Delists ERC20 address to prevent adding new yield contracts with this ERC20 collateral
   * @param _ERC20Address - Address of the ERC20 contract
   * @param _isValid - New validity boolean of the ERC20 contract
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function setERC20Validity(address _ERC20Address, bool _isValid) public onlyOwner() inERC20List(_ERC20Address) returns(bool ) {

    // Set valid ERC20 validity
    ERC20Map[_ERC20Address].isValid = _isValid;
    return true;
  }

  /**
   * @dev Updates the mint factor of a coin/token
   * @param _ERC20Address - Address of the ERC20 contract or ETH address (ZERO_ADDRESS)
   * @return - Boolean status - True indicating successful completion
   * @notice - Access control: Only Owner
   */
  function updateMFactor(address _ERC20Address, uint256 _mFactor) public onlyOwner() inERC20List(_ERC20Address) onlyERC20OrETH(_ERC20Address) returns(bool ) {

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
    for(uint256 i = 0; i < _ERC20AddressList.length; i++) {
      updateMFactor(_ERC20AddressList[i],_mFactorList[i]);
    }
    return true;
  }

  /**
   * @dev Returns number of valid Tokens/Coins supported
   * @return - Number of valid tokens/coins
   * @notice - Access control: Public
   */
  function getNoOfERC20s() public view returns(uint256 ) {
    return(ERC20List.length);
    
  }

  /**
   * @dev Returns subset list of valid ERC20 contracts
   * @param _start - Start index to search in the list
   * @param _end - End index to search in the list
   * @return - List of valid ERC20 addresses subset
   * @notice - Access control: Public
   */
  function getSubsetERC20List(uint256 _start, uint256 _end) public view returns(address[] memory ) {

    // If _end higher than length of array, set end index to last element of the array
    if(_end >= ERC20List.length) {
      _end = ERC20List.length.sub(1);
    }

    // Check conditions else fail
    require(_start <= _end, "Invalid limits");

    // Define return array
    uint256 noOfElements = _end.sub(_start).add(1);
    address[] memory subsetERC20List = new address[](noOfElements);

    // Loop in and add elements from ERC20List array
    for(uint256 i = _start; i <= _end; i++) {
      subsetERC20List[i - _start] = ERC20List[i];
    }
    return subsetERC20List;
  }

  /**
   * YIELD CONTRACT FUNCTIONS
   */

  /**
   * @dev Creates a yield contract
   * @param _ERC20Address - The address of the ERC20 token (ZERO_ADDRESS if ETH)
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
    bytes32 contractId = keccak256(abi.encode(msg.sender, _ERC20Address, now, allContracts.length));
    require(contractMap[contractId].contractStatus == Status.inactive, "Contract already exists");

    // Check if APY (interest rate is not zero for the tenure)
    require(tenureApyMap[_tenure] != 0, "No interest rate is set");

    // Get decimal value for collaterals
    uint256 collateralDecimals;

    // Check id collateral is not 0
    require(_collateral != 0,"Collateral is 0");

    if(_ERC20Address == ZERO_ADDRESS) {

      // In case of ETH, check to ensure if collateral value match ETH sent
      require(msg.value == _collateral,"Incorrect funds");

      // ETH decimals is 18
      collateralDecimals = 10 ** 18;     

    } else {

      // In case of non ETH, check to ensure if msg.value is 0
      require(msg.value == 0,"Incorrect funds");      

      collateralDecimals = 10 ** uint256(ERC20(_ERC20Address).decimals());

      // Transfer collateral
      ERC20(_ERC20Address).safeTransferFrom(msg.sender, address(this),_collateral);
    }

    // Calculate MXX to be Minted
    uint256 numerator = _collateral
                          .mul(ERC20Map[_ERC20Address].mFactor)
                          .mul(tenureApyMap[_tenure])
                          .mul(10 ** uint256(ERC20(MXX_ADDRESS).decimals()))
                          .mul(_tenure);
    uint256 denominator = collateralDecimals
                            .mul(ERC20Map[MXX_ADDRESS].mFactor)
                            .mul(365 *(10 ** 6));
    uint256 valueToBeMinted = numerator.div(denominator);

    // Update total MXX minted from yield contracts
    mxxMintedFromContract = mxxMintedFromContract.add(valueToBeMinted);

    // Check the MXX to be minted will result in total MXX allocated for creating yield contracts
    require(totalAllocatedMxx >= mxxMintedFromContract, "Total allocated MXX exceeded");

    // Calculate MXX to be burnt 
    numerator = valueToBeMinted
                  .mul(contractFee);
    denominator = 10 ** 6;  
    uint256 valueToBeBurnt = numerator.div(denominator);

    // Send valueToBeBurnt to contract fee destination
    ERC20(MXX_ADDRESS).safeTransferFrom(msg.sender, BURN_ADDRESS, valueToBeBurnt);

    // Create contract
    contractMap[contractId] = contractDetails(msg.sender,uint48(now),uint48(now.add(uint256(_tenure).mul(1 days))),_ERC20Address,_tenure,tenureApyMap[_tenure],Status.active,_collateral,valueToBeMinted);

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
    require(contractMap[_contractId].contractStatus == Status.active,"Contract is not active");

    // Check if redeemer is the owner
    require(contractMap[_contractId].contractOwner == msg.sender,"Redeemer is not owner");

    // Check if current time is less than end time
    require(now < contractMap[_contractId].endTime, "Contract is beyond its end time");

    // Calculate mxxMintedTillDate
    uint256 numerator = now
                          .sub(contractMap[_contractId].startTime)
                          .mul(contractMap[_contractId].mxxToBeMinted);
    uint256 denominator = uint256(contractMap[_contractId].endTime).sub(contractMap[_contractId].startTime);
    uint256 mxxMintedTillDate = numerator.div(denominator);

    // Calculate penaltyPercent
    numerator = uint256(maxEarlyRedeemFee)
                  .sub(minEarlyRedeemFee)
                  .mul(now.sub(contractMap[_contractId].startTime));
    uint256 penaltyPercent = uint256(maxEarlyRedeemFee).sub(numerator.div(denominator));

    // Calculate penaltyMXXToBurn
    numerator = penaltyPercent.mul(mxxMintedTillDate);
    denominator = 10 ** 6;
    uint256 penaltyMXXToBurn = numerator.div(denominator);

    // Check if penalty MXX to burn is not 0
    require(penaltyMXXToBurn > 0,"No penalty MXX");

    // Calculate mxxToBeSent
    uint256 mxxToBeSent = mxxMintedTillDate.sub(penaltyMXXToBurn);

    // Return collateral
    if(contractMap[_contractId].tokenAddress == ZERO_ADDRESS) {

      // Send back ETH
      (bool success, ) = contractMap[_contractId].contractOwner.call{value: contractMap[_contractId].collateral}("");
      require(success, "Transfer failed");
    } else {
      // Send back ERC20 collateral
      ERC20(contractMap[_contractId].tokenAddress).safeTransfer(contractMap[_contractId].contractOwner, contractMap[_contractId].collateral);      
    }

    // Return MXX
    ERC20(MXX_ADDRESS).safeTransfer(contractMap[_contractId].contractOwner, mxxToBeSent);

    // Burn penalty fee
    ERC20(MXX_ADDRESS).safeTransfer(BURN_ADDRESS, penaltyMXXToBurn);

    // Updating contract 
    contractMap[_contractId].startTime = uint48(now);
    contractMap[_contractId].mxxToBeMinted = contractMap[_contractId].mxxToBeMinted.sub(mxxMintedTillDate);
    contractMap[_contractId].contractOwner = ZERO_ADDRESS;
    contractMap[_contractId].contractStatus = Status.openMarket;  
  }

  /**
   * @dev Acquire a yield contract in the open market
   * @param _contractId - The Id of the contract
   * Non Reentrant modifier is used to prevent re-entrancy attack
   * @notice - Access control: External
   */
  
  function acquireYieldContract(bytes32 _contractId) external nonReentrant() payable {

    // Check if contract is open
    require(contractMap[_contractId].contractStatus == Status.openMarket,"Contract not in open market");

    // Get collateral in case of ERC20 tokens, for ETH it is already received via msg.value
    if(contractMap[_contractId].tokenAddress != ZERO_ADDRESS) {

      // In case of ERC20, ensure no ETH is sent
      require(msg.value == 0, "ETH should not be sent");
      ERC20(contractMap[_contractId].tokenAddress).safeTransferFrom(msg.sender, address(this),contractMap[_contractId].collateral);
    } else {

      // In case of ETH check if money received equals the collateral else revert
      require(msg.value == contractMap[_contractId].collateral, "Incorrect funds");
    }

    // Updating contract 
    contractMap[_contractId].contractOwner = msg.sender;
    contractMap[_contractId].contractStatus = Status.active;    
  }

  /**
   * @dev Destory an open market yield contract
   * @param _contractId - The Id of the contract
   * Non Reentrant modifier is used to prevent re-entrancy attack
   * @notice - Access control: External
   */
  
  function destroyOMContract(bytes32 _contractId) external  onlyOwner() nonReentrant() {

    // Check if contract is open
    require(contractMap[_contractId].contractStatus == Status.openMarket,"Contract not in open market");

    // Reduced MXX minted from contract and update status as destroyed 
    mxxMintedFromContract -= contractMap[_contractId].mxxToBeMinted;
    contractMap[_contractId].contractStatus = Status.destroyed;    
  } 

  /**
   * @dev Claim a yield contract in the active market
   * @param _contractId - The Id of the contract
   * Non Reentrant modifier is used to prevent re-entrancy attack
   * @notice - Access control: External
   */
  
  function claimYieldContract(bytes32 _contractId) external nonReentrant() {

    // Check if contract is active
    require(contractMap[_contractId].contractStatus == Status.active,"Contract is not active");

    // Check if owner and msg.sender are the same
    require(contractMap[_contractId].contractOwner == msg.sender,"Contract owned by someone else");

    // Check if current time is greater than contract end time
    require(now >= contractMap[_contractId].endTime, "Too early to claim");

    // Return collateral
    if(contractMap[_contractId].tokenAddress == ZERO_ADDRESS) {

      // Send back ETH
      (bool success, ) = contractMap[_contractId].contractOwner.call{value: contractMap[_contractId].collateral}("");
      require(success, "Transfer failed");
    } else {
      // Send back ERC20 collateral
      ERC20(contractMap[_contractId].tokenAddress).safeTransfer(contractMap[_contractId].contractOwner, contractMap[_contractId].collateral);      
    }

    // Return minted MXX
    ERC20(MXX_ADDRESS).safeTransfer(contractMap[_contractId].contractOwner, contractMap[_contractId].mxxToBeMinted);


    // Updating contract 
    contractMap[_contractId].contractStatus = Status.claimed;

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
  
  function getSubsetYieldContracts(uint256 _start, uint256 _end) public view returns(bytes32[] memory ) {

    // If _end higher than length of array, set end index to last element of the array
    if(_end >= allContracts.length) {
      _end = allContracts.length.sub(1);
    }

    // Check conditions else fail
    require(_start <= _end, "Invalid limits");

    // Define return array
    uint256 noOfElements = _end.sub(_start).add(1);
    bytes32[] memory subsetYieldContracts = new bytes32[](noOfElements);

    // Loop in and add elements from allContracts array
    for(uint256 i = _start; i <= _end; i++) {
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
    ERC20(MXX_ADDRESS).safeTransfer(msg.sender, _amount);
    return true;
  }
}