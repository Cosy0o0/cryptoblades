pragma solidity ^0.6.5;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IRandoms.sol";
import "./shields.sol";
import "./Consumables.sol";
import "./weapons.sol";
import "./cryptoblades.sol";

contract Blacksmith is Initializable, AccessControlUpgradeable {
    /* ========== CONSTANTS ========== */

    bytes32 public constant GAME = keccak256("GAME");

    uint256 public constant SHIELD_SKILL_FEE = 3 ether;

    uint256 public constant ITEM_WEAPON_RENAME = 1;
    uint256 public constant ITEM_CHARACTER_RENAME = 2;
    uint256 public constant ITEM_CHARACTER_TRAITCHANGE_FIRE = 3;
    uint256 public constant ITEM_CHARACTER_TRAITCHANGE_EARTH = 4;
    uint256 public constant ITEM_CHARACTER_TRAITCHANGE_WATER = 5;
    uint256 public constant ITEM_CHARACTER_TRAITCHANGE_LIGHTNING = 6;
    uint256 public constant ITEM_SMOKE_BOMB = 7;
    uint256 public constant ITEM_EXP_SCROLL = 8;

    /* ========== STATE VARIABLES ========== */

    Weapons public weapons;
    IRandoms public randoms;

    mapping(address => uint32) public tickets;

    Shields public shields;
    CryptoBlades public game;

    // keys: ITEM_ constant
    mapping(uint256 => address) public itemAddresses;
    mapping(uint256 => uint256) public itemFlatPrices;

    /* ========== Events ========== */

    event purchaseMade(address indexed buyer, uint256 item, uint8 amount, uint256 payed);

    /* ========== INITIALIZERS AND MIGRATORS ========== */

    function initialize(Weapons _weapons, IRandoms _randoms)
        public
        initializer
    {
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        weapons = _weapons;
        randoms = _randoms;
    }

    function migrateRandoms(IRandoms _newRandoms) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        randoms = _newRandoms;
    }

    function migrateTo_61c10da(Shields _shields, CryptoBlades _game) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");

        shields = _shields;
        game = _game;
    }

    function migrateTo_16884dd(
        address _characterRename,
        address _weaponRename,
        address _charFireTraitChange,
        address _charEarthTraitChange,
        address _charWaterTraitChange,
        address _charLightningTraitChange
    ) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        itemAddresses[ITEM_WEAPON_RENAME] = _weaponRename;
        itemAddresses[ITEM_CHARACTER_RENAME] = _characterRename;
        itemAddresses[ITEM_CHARACTER_TRAITCHANGE_FIRE] = _charFireTraitChange;
        itemAddresses[ITEM_CHARACTER_TRAITCHANGE_EARTH] = _charEarthTraitChange;
        itemAddresses[ITEM_CHARACTER_TRAITCHANGE_WATER] = _charWaterTraitChange;
        itemAddresses[ITEM_CHARACTER_TRAITCHANGE_LIGHTNING] = _charLightningTraitChange;

        itemFlatPrices[ITEM_WEAPON_RENAME] = 0.1 ether;
        itemFlatPrices[ITEM_CHARACTER_RENAME] = 0.1 ether;
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_FIRE] = 0.2 ether;
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_EARTH] = 0.2 ether;
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_WATER] = 0.2 ether;
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_LIGHTNING] = 0.2 ether;
    }

    function migrateTo_cdd5968(address _smokeBomb, address _expScroll) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        
        itemAddresses[ITEM_SMOKE_BOMB] = _smokeBomb;
        itemFlatPrices[ITEM_SMOKE_BOMB] = 0.01 ether;

        itemAddresses[ITEM_EXP_SCROLL] = _expScroll;
        itemFlatPrices[ITEM_EXP_SCROLL] = 0.1 ether;
    }

    /* ========== VIEWS ========== */

    /* ========== MUTATIVE FUNCTIONS ========== */

    // function spendTicket(uint32 _num) external {
    //     require(_num > 0);
    //     require(tickets[msg.sender] >= _num, "Not enough tickets");
    //     tickets[msg.sender] -= _num;

    //     for (uint256 i = 0; i < _num; i++) {
    //         weapons.mint(
    //             msg.sender,
    //             // TODO: Do the thing we do in cryptoblades.sol to "lock in" the user into a given blockhash
    //         );
    //     }
    // }

    function giveTicket(address _player, uint32 _num) external onlyGame {
        tickets[_player] += _num;
    }

    function purchaseShield() public {
        Promos promos = game.promos();
        uint256 BIT_LEGENDARY_DEFENDER = promos.BIT_LEGENDARY_DEFENDER();

        require(!promos.getBit(msg.sender, BIT_LEGENDARY_DEFENDER), "Limit 1");
        promos.setBit(msg.sender, BIT_LEGENDARY_DEFENDER);
        game.payContractTokenOnly(msg.sender, SHIELD_SKILL_FEE);
        shields.mintForPurchase(msg.sender);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyGame() {
        require(hasRole(GAME, msg.sender), "Only game");
        _;
    }

     modifier isAdmin() {
         require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    /* ========== Generic Getters ========== */

    function getAddressOfItem(uint256 itemIndex) public view returns(address) {
        return itemAddresses[itemIndex];
    }

    function getFlatPriceOfItem(uint256 itemIndex) public view returns(uint256) {
        return itemFlatPrices[itemIndex];
    }

    /* ========== Character Rename ========== */
    
    function setCharacterRenamePrice(uint256 newPrice) external isAdmin {
        require(newPrice > 0, 'invalid price');
        itemFlatPrices[ITEM_CHARACTER_RENAME] = newPrice;
    }

    function characterRenamePrice() public view returns (uint256){
        return itemFlatPrices[ITEM_CHARACTER_RENAME];
    }

    function purchaseCharacterRenameTag(uint256 paying) public {
        require(paying == itemFlatPrices[ITEM_CHARACTER_RENAME], 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_CHARACTER_RENAME]);
        Consumables(itemAddresses[ITEM_CHARACTER_RENAME]).giveItem(msg.sender, 1);
        purchaseMade(msg.sender, ITEM_CHARACTER_RENAME, 1, itemFlatPrices[ITEM_CHARACTER_RENAME]);
    }
    
    function purchaseCharacterRenameTagDeal(uint256 paying) public { // 4 for the price of 3
        require(paying == itemFlatPrices[ITEM_CHARACTER_RENAME] * 3, 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_CHARACTER_RENAME] * 3);
        Consumables(itemAddresses[ITEM_CHARACTER_RENAME]).giveItem(msg.sender, 4);
        purchaseMade(msg.sender, ITEM_CHARACTER_RENAME, 4, itemFlatPrices[ITEM_CHARACTER_RENAME] * 3);
    }
    
    /* ========== Weapon Rename ========== */

    function setWeaponRenamePrice(uint256 newPrice) external isAdmin {
        require(newPrice > 0, 'invalid price');
        itemFlatPrices[ITEM_WEAPON_RENAME] = newPrice;
    }

    function weaponRenamePrice() public view returns (uint256){
        return itemFlatPrices[ITEM_WEAPON_RENAME];
    }

    function purchaseWeaponRenameTag(uint256 paying) public {
        require(paying == itemFlatPrices[ITEM_WEAPON_RENAME], 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_WEAPON_RENAME]);
        Consumables(itemAddresses[ITEM_WEAPON_RENAME]).giveItem(msg.sender, 1);
        emit purchaseMade(msg.sender, ITEM_WEAPON_RENAME, 1, itemFlatPrices[ITEM_WEAPON_RENAME]);
    }

    function purchaseWeaponRenameTagDeal(uint256 paying) public { // 4 for the price of 3
        require(paying == itemFlatPrices[ITEM_WEAPON_RENAME] * 3, 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_WEAPON_RENAME] * 3);
        Consumables(itemAddresses[ITEM_WEAPON_RENAME]).giveItem(msg.sender, 4);
        emit purchaseMade(msg.sender, ITEM_WEAPON_RENAME, 4, itemFlatPrices[ITEM_WEAPON_RENAME] * 3);
    }

     /* ========== Character Trait Change ========== */

     function setCharacterTraitChangePrice(uint256 newPrice) external isAdmin {
        require(newPrice > 0, 'invalid price');
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_FIRE] = newPrice;
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_EARTH] = newPrice;
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_WATER] = newPrice;
        itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_LIGHTNING] = newPrice;
    }

     function characterTraitChangePrice() public view returns (uint256){
        return itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_FIRE];
    }

    function purchaseCharacterFireTraitChange(uint256 paying) public {
        require(paying == itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_FIRE], 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_FIRE]);
        Consumables(itemAddresses[ITEM_CHARACTER_TRAITCHANGE_FIRE]).giveItem(msg.sender, 1);
        emit purchaseMade(msg.sender, ITEM_CHARACTER_TRAITCHANGE_FIRE, 1, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_FIRE]);
    }

    function purchaseCharacterEarthTraitChange(uint256 paying) public {
        require(paying == itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_EARTH], 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_EARTH]);
        Consumables(itemAddresses[ITEM_CHARACTER_TRAITCHANGE_EARTH]).giveItem(msg.sender, 1);
        emit purchaseMade(msg.sender, ITEM_CHARACTER_TRAITCHANGE_EARTH, 1, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_EARTH]);
    }

    function purchaseCharacterWaterTraitChange(uint256 paying) public {
        require(paying == itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_WATER], 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_WATER]);
        Consumables(itemAddresses[ITEM_CHARACTER_TRAITCHANGE_WATER]).giveItem(msg.sender, 1);
        emit purchaseMade(msg.sender, ITEM_CHARACTER_TRAITCHANGE_WATER, 1, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_WATER]);
    }

    function purchaseCharacterLightningTraitChange(uint256 paying) public {
        require(paying == itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_LIGHTNING], 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_LIGHTNING]);
        Consumables(itemAddresses[ITEM_CHARACTER_TRAITCHANGE_LIGHTNING]).giveItem(msg.sender, 1);
        emit purchaseMade(msg.sender, ITEM_CHARACTER_TRAITCHANGE_LIGHTNING, 1, itemFlatPrices[ITEM_CHARACTER_TRAITCHANGE_LIGHTNING]);
    }

    /* ========== Smoke Bomb ========== */
      function setSmokeBombPrice(uint256 newPrice) external isAdmin {
        require(newPrice > 0, 'invalid price');
        itemFlatPrices[ITEM_SMOKE_BOMB] = newPrice;
    }

    function getSmokeBombPrice() public view returns (uint256){
        return itemFlatPrices[ITEM_SMOKE_BOMB];
    }

     function purchase10SmokeBombs(uint256 paying) public { 
        require(paying == itemFlatPrices[ITEM_SMOKE_BOMB] * 10, 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_SMOKE_BOMB] * 10);
        Consumables(itemAddresses[ITEM_SMOKE_BOMB]).giveItem(msg.sender, 10);
        emit purchaseMade(msg.sender, ITEM_SMOKE_BOMB, 10, itemFlatPrices[ITEM_SMOKE_BOMB] * 10);
    }


    /* ========== Exp scroll ========== */
      function setExpScrollPrice(uint256 newPrice) external isAdmin {
        require(newPrice > 0, 'invalid price');
        itemFlatPrices[ITEM_EXP_SCROLL] = newPrice;
    }

    function getExpScrollPrice() public view returns (uint256){
        return itemFlatPrices[ITEM_EXP_SCROLL];
    }

     function purchaseExpScroll(uint256 paying) public { 
        require(paying == itemFlatPrices[ITEM_EXP_SCROLL], 'Invalid price');
        game.payContractTokenOnly(msg.sender, itemFlatPrices[ITEM_EXP_SCROLL]);
        Consumables(itemAddresses[ITEM_EXP_SCROLL]).giveItem(msg.sender, 1);
        emit purchaseMade(msg.sender, ITEM_EXP_SCROLL, 1, itemFlatPrices[ITEM_EXP_SCROLL]);
    }
}
