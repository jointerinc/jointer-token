pragma solidity ^0.5.9;


//on ropsten : 0x59DdAdcE870827186fC0aB55d8BFA9C601c3C4C0
//on matic: 0x58AaBb5dbE1DA9329Dc45eBac9b6476c1BDe2213
contract ERC20 {
    // --- Auth ---
    mapping(address => uint256) public wards;

    function rely(address guy) public auth {
        wards[guy] = 1;
    }

    function deny(address guy) public auth {
        wards[guy] = 0;
    }

    modifier auth {
        require(wards[msg.sender] == 1);
        _;
    }

    // --- ERC20 Data ---
    uint8 public decimals = 18;
    string public name;
    string public symbol;
    string public version;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    // --- Math ---
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "math-sub-underflow");
    }

    // --- EIP712 niceties ---
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)"
    );

    constructor(
        string memory symbol_,
        string memory name_,
        string memory version_,
        uint256 chainId_
    ) public {
        wards[msg.sender] = 1;
        symbol = symbol_;
        name = name_;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Dai Semi-Automated Permit Office"),
                keccak256(bytes(version_)),
                chainId_,
                address(this)
            )
        );
    }

    // --- Token ---
    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad)
        public
        returns (bool)
    {
        if (src != msg.sender && allowance[src][msg.sender] != uint256(-1)) {
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }

    function mint(address usr, uint256 wad) public auth {
        balanceOf[usr] = add(balanceOf[usr], wad);
        totalSupply = add(totalSupply, wad);
        emit Transfer(address(0), usr, wad);
    }

    function burn(address usr, uint256 wad) public {
        if (usr != msg.sender && allowance[usr][msg.sender] != uint256(-1)) {
            allowance[usr][msg.sender] = sub(allowance[usr][msg.sender], wad);
        }
        balanceOf[usr] = sub(balanceOf[usr], wad);
        totalSupply = sub(totalSupply, wad);
        emit Transfer(usr, address(0), wad);
    }

    function approve(address usr, uint256 wad) public returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }

    // --- Alias ---
    function push(address usr, uint256 wad) public {
        transferFrom(msg.sender, usr, wad);
    }

    function pull(address usr, uint256 wad) public {
        transferFrom(usr, msg.sender, wad);
    }

    function move(address src, address dst, uint256 wad) public {
        transferFrom(src, dst, wad);
    }

    // --- Approve by signature ---
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        holder,
                        spender,
                        nonce,
                        expiry,
                        allowed
                    )
                )
            )
        );
        require(holder == ecrecover(digest, v, r, s), "invalid permit");
        require(expiry == 0 || now <= expiry, "permit expired");
        require(nonce == nonces[holder]++, "invalid nonce");
        uint256 wad = allowed ? uint256(-1) : 0;
        allowance[holder][spender] = wad;
        emit Approval(holder, spender, wad);
    }
}
