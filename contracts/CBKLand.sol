pragma solidity ^0.6.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./util.sol";

contract CBKLand is Initializable, ERC721Upgradeable, AccessControlUpgradeable {

    bytes32 public constant GAME_ADMIN = keccak256("GAME_ADMIN");
    bytes32 public constant NO_OWNED_LIMIT = keccak256("NO_OWNED_LIMIT");

    // Land specific
    uint256 public constant LT = 0; // Land Tier
    uint256 public constant LC = 1; // Land Chunk Id
    uint256 public constant LX = 2; // Land Coordinate X
    uint256 public constant LY = 3; // Land Coordinate Y

    event LandMinted(address indexed minter, uint256 id, uint256 tier, uint256 chunkId);
    event LandTransfered(address indexed from, address indexed to, uint256 id);

    // TotalLand
    uint256 landMinted;
    // Avoiding structs for stats
    mapping(uint256 => mapping(uint256 => uint256)) landData;

    uint256 public constant LSU = 0; // URI
    mapping(uint256 => mapping(uint256 => string)) landStrData;

    function initialize () public initializer {
        __ERC721_init("CryptoBladesKingdoms Land", "CBKL");
        __AccessControl_init_unchained();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier restricted() {
        _restricted();
        _;
    }

    function _restricted() internal view {
        require(hasRole(GAME_ADMIN, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "NA");
    }

    function get(uint256 id) public view returns (uint256, uint256, uint256, uint256) {
        return (landData[id][LT], landData[id][LC], landData[id][LX], landData[id][LY]);
    }

    // tier, chunkid, x, y
    function getOwned(address owner) public view returns (uint256, uint256, uint256, uint256) {
        uint256 id = tokenOfOwnerByIndex(owner, 0);
        return get(id);
    }

    // DO NOT call directly outside the logic of CBKLandSale to avoid breaking tier and chunk logic
    function mint(address minter, uint256 tier, uint256 chunkId) public restricted {
        mint(minter, tier, chunkId, '');
    }

    // DO NOT call directly outside the logic of CBKLandSale to avoid breaking tier and chunk logic
    function mint(address minter, uint256 tier, uint256 chunkId, string memory uri) public restricted {
        uint256 tokenID = landMinted++;
        
        landData[tokenID][LT] = tier;
        landData[tokenID][LC] = chunkId;
        //landData[tokenID][LX] = x; // not yet
        //landData[tokenID][LY] = y; // not yet
        
        _mint(minter, tokenID);
        _setURI(tokenID, uri);
        emit LandMinted(minter, tokenID, tier, chunkId);
    }

    function _setURI(uint256 id, string memory uri) internal {
        landStrData[id][LSU] = uri;
    }

    function setURI(uint256 id, string memory uri) public restricted {
        _setURI(id, uri);
    }

    function getURI(uint256 id) public view returns (string memory uri) {
        uri = landStrData[id][LSU];
    }

    // TODO: block land transfer
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if(to != address(0) && to != address(0x000000000000000000000000000000000000dEaD) && !hasRole(NO_OWNED_LIMIT, to)) {
            require(balanceOf(to) == 0, "Recv has purchased a land");
        }

        emit LandTransfered(from, to, tokenId);
    }
}
