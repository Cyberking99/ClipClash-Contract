// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ClipClash is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    IERC20 public clashToken;

    struct Battle {
        uint256 battleId;
        address creator1;
        address creator2;
        string ipfsHash1;
        string ipfsHash2;
        string category;
        uint256 entryFee;
        uint256 votingEndTime;
        uint256 votes1;
        uint256 votes2;
        address winner;
        bool isActive;
    }
    
    uint256 public battleCount;
    mapping(uint256 => Battle) public battles;
    mapping(address => uint256) public creatorBattles;
    mapping(uint256 => mapping(address => uint256)) public votesPerBattle;

    uint256 public constant VOTING_DURATION = 1 days;
    uint256 public constant MIN_ENTRY_FEE = 1 ether;

    address public treasury;

    event BattleCreated(
        uint256 indexed battleId,
        address creator1,
        string category,
        uint256 entryFee
    );
    event ClipSubmitted(
        uint256 indexed battleId,
        address indexed creator,
        string ipfsHash
    );



    // Constructor
    constructor(address _clashToken, address _treasury) Ownable(msg.sender) {
        clashToken = IERC20(_clashToken);
        treasury = _treasury;
    }

    // Create a new battle
    function createBattle(
        string memory _category,
        uint256 _entryFee,
        string memory _ipfsHash1
    ) external nonReentrant {
        require(msg.sender != address(0), "Invalid creator");
        require(_entryFee >= MIN_ENTRY_FEE, "Entry fee too low");
        require(creatorBattles[msg.sender] == 0, "Finish your active battle");
        require(bytes(_ipfsHash1).length > 0, "Invalid IPFS hash");
        
        clashToken.safeTransferFrom(msg.sender, address(this), _entryFee);

        battleCount++;
        Battle storage newBattle = battles[battleCount];
        newBattle.battleId = battleCount;
        newBattle.creator1 = msg.sender;
        newBattle.creator2 = address(0);
        newBattle.ipfsHash1 = _ipfsHash1;
        newBattle.category = _category;
        newBattle.entryFee = _entryFee;
        newBattle.votingEndTime = block.timestamp + VOTING_DURATION;
        newBattle.isActive = true;

        creatorBattles[msg.sender] =battleCount;

        emit BattleCreated(battleCount, msg.sender, _category, _entryFee);
        emit ClipSubmitted(battleCount, msg.sender, _ipfsHash1);
    }

    function submitClip(uint256 _battleId, string memory _ipfsHash2) external nonReentrant {
        Battle storage battle = battles[_battleId];
        require(battle.isActive, "Battle not active");
        require(battle.creator2 == address(0), "Creator2 already exist");
        require(bytes(battle.ipfsHash2).length == 0, "Clip already submitted");
        require(bytes(_ipfsHash2).length > 0, "Invalid IPFS hash");

        battle.creator2 = msg.sender;
        clashToken.safeTransferFrom(msg.sender, address(this), battle.entryFee);

        battle.ipfsHash2 = _ipfsHash2;
        creatorBattles[msg.sender] = _battleId;

        emit ClipSubmitted(_battleId, msg.sender, _ipfsHash2);
    }
}
