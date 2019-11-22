pragma solidity 0.5.9;

contract Ownable {


  address public primaryOwner = address(0);
  address public secondaryOwner = address(0);
  address public systemAddress = address(0);


   /**
   * @dev The Ownable constructor sets the `owners` and `systemAddress`
   * account.
   */

   constructor(address _secondaryOwner,address _systemAddress) public {
     primaryOwner = msg.sender;
     secondaryOwner = _secondaryOwner;
     systemAddress = _systemAddress;
   }



  mapping (address => mapping (address => bool)) public primaryOwnerAllowed;
  mapping (address => mapping (address => bool)) public secondaryOwnerAllowed;
  mapping (address => mapping (address => bool)) public systemAddressAllowed;

  event OwnershipTransferred(string typeTran,address indexed previousOwner, address indexed newOwner);
  event AllowChangeOwner(string typeTran,address indexed _allowedBy,address indexed _allowed,bool _isAllowed);




  modifier onlyOwner() {
    require(msg.sender == primaryOwner || msg.sender == secondaryOwner,"ONLY OWNER ADDRESS CAN PERFORM ACTION");
    _;
  }

  modifier onlySystem() {
    require(msg.sender == primaryOwner ||
            msg.sender == secondaryOwner ||
            msg.sender == systemAddress,"ONLY ALLOWED ADDRESS CAN PERFORM ACTION");
    _;
  }


  modifier onlyPrimaryOwner() {
    require(msg.sender == primaryOwner,"ONLY PRIMARY OWNER CAN PERFORM ACTION");
    _;
  }

  modifier onlysecondaryOwner (){
    require(msg.sender == secondaryOwner,"ONLY SECONDARY OWNER CAN PERFORM ACTION");
    _;
  }

  modifier notOwnAddress(address _address) {
    require(msg.sender != _address,"CAN NOT SET OWN ADDRESS");
    _;
  }


  function allowChangePrimaryOwner(address _address,bool _isAllowed) public onlyOwner notOwnAddress(_address) returns(bool){
      primaryOwnerAllowed[msg.sender][_address] = _isAllowed;
      emit AllowChangeOwner("PRIMARY_OWNER",msg.sender,_address,_isAllowed);
  }

  function allowChangeSecondaryOwner(address _address,bool _isAllowed) public onlyOwner notOwnAddress(_address) returns(bool){
      secondaryOwnerAllowed[msg.sender][_address] = _isAllowed;
      emit AllowChangeOwner("SECONDARY_OWNER",msg.sender,_address,_isAllowed);
  }

  function allowChangeSystemAddress(address _address,bool _isAllowed) public onlyOwner notOwnAddress(_address) returns(bool){
      systemAddressAllowed[msg.sender][_address] = _isAllowed;
      emit AllowChangeOwner("SYSTEM_ADDRESS",msg.sender,_address,_isAllowed);
  }


  function acceptPrimaryOwnership() public returns(bool){
    require(primaryOwnerAllowed[primaryOwner][msg.sender] && primaryOwnerAllowed[secondaryOwner][msg.sender]);
    emit OwnershipTransferred("PRIMARY_OWNER",primaryOwner,msg.sender);
    primaryOwner = msg.sender;
    primaryOwnerAllowed[primaryOwner][msg.sender] = false;
    primaryOwnerAllowed[secondaryOwner][msg.sender] = false;
  }

  function acceptSecondaryOwnership() public returns(bool){
    require(secondaryOwnerAllowed[primaryOwner][msg.sender] && secondaryOwnerAllowed[secondaryOwner][msg.sender]);
    emit OwnershipTransferred("SECONDARY_OWNER",secondaryOwner,msg.sender);
    secondaryOwner = msg.sender;
    secondaryOwnerAllowed[primaryOwner][msg.sender] = false;
    secondaryOwnerAllowed[secondaryOwner][msg.sender] =  false;
  }

  function acceptSystemAddressOwnership() public returns(bool){
    require(systemAddressAllowed[primaryOwner][msg.sender] && systemAddressAllowed[secondaryOwner][msg.sender]);
    emit OwnershipTransferred("SYSTEM_ADDRESS",systemAddress,msg.sender);
    systemAddress = msg.sender;
    systemAddressAllowed[primaryOwner][msg.sender] = false;
    systemAddressAllowed[secondaryOwner][msg.sender] = false;
  }
}
