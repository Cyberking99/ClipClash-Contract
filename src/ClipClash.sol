// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ClipClash is Ownable, ReentrancyGuard {

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
        address creator2,
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
        address _creator2,
        string memory _category,
        uint256 _entryFee,
        string memory _ipfsHash1
    ) external nonReentrant {
        require(_creator2 != msg.sender, "Cannot challenge yourself");
        require(_entryFee >= MIN_ENTRY_FEE, "Entry fee too low");
        require(creatorBattles[msg.sender] == 0, "Finish your active battle");
        require(creatorBattles[_creator2] == 0, "Opponent is in active battle");
        require(bytes(_ipfsHash1).length > 0, "Invalid IPFS hash");

        // Transfer entry fee from creator1
        require(
            clashToken.transferFrom(msg.sender, address(this), _entryFee),
            "Entry fee transfer failed"
        );

        battleCount++;
        Battle storage newBattle = battles[battleCount];
        newBattle.battleId = battleCount;
        newBattle.creator1 = msg.sender;
        newBattle.creator2 = _creator2;
        newBattle.ipfsHash1 = _ipfsHash1;
        newBattle.category = _category;
        newBattle.entryFee = _entryFee;
        newBattle.votingEndTime = block.timestamp + VOTING_DURATION;
        newBattle.isActive = true;

        creatorBattles[msg.sender] =battleCount;

        emit BattleCreated(battleCount, msg.sender, _creator2, _category, _entryFee);
        emit ClipSubmitted(battleCount, msg.sender, _ipfsHash1);
    }
}
