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

    struct UserProfile {
        string username;
        uint256 reputation;
        uint256 totalBattles;
        uint256 totalWins;
        uint256[] clipIds;
        uint256[] battleIds;
        bool isRegistered;
    }
    
    uint256 public battleCount;
    mapping(uint256 => Battle) public battles;
    mapping(address => uint256) public creatorBattles;
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => mapping(address => uint256)) public votesPerBattle;
    mapping(string => address) public usernameToAddress;


    uint256 public constant VOTING_DURATION = 1 days;
    uint256 public constant MIN_ENTRY_FEE = 1 ether;
    uint256 public constant CREATOR_REWARD_PERCENT = 70; // 70% of entry fees to winner
    uint256 public constant VOTER_REWARD_PERCENT = 20; // 20% of entry fees to voters
    uint256 public constant PROTOCOL_FEE_PERCENT = 10; // 10% to protocol treasury

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
    event Voted(
        uint256 indexed battleId,
        address indexed voter,
        address indexed creator,
        uint256 amount
    );
    event BattleEnded(
        uint256 indexed battleId,
        address indexed winner,
        uint256 creatorReward,
        uint256 voterReward
    );
    event RewardsDistributed(
        uint256 indexed battleId,
        address indexed recipient,
        uint256 amount
    );
    event UserRegistered(
        address indexed userAddress,
        string username
    );

    // Constructor
    constructor(address _clashToken, address _treasury) Ownable(msg.sender) {
        clashToken = IERC20(_clashToken);
        treasury = _treasury;
    }
    
    function registerUser(string memory _username) external {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(bytes(_username).length <= 32, "Username too long");
        require(!userProfiles[msg.sender].isRegistered, "User already registered");
        require(usernameToAddress[_username] == address(0), "Username already taken");

        UserProfile storage profile = userProfiles[msg.sender];
        profile.username = _username;
        profile.isRegistered = true;
        
        usernameToAddress[_username] = msg.sender;

        emit UserRegistered(msg.sender, _username);
    }

    // Update username
    function updateUsername(string memory _newUsername) external {
        require(userProfiles[msg.sender].isRegistered, "User not registered");
        require(bytes(_newUsername).length > 0, "Username cannot be empty");
        require(bytes(_newUsername).length <= 32, "Username too long");
        require(usernameToAddress[_newUsername] == address(0), "Username already taken");

        string memory oldUsername = userProfiles[msg.sender].username;
        
        // Remove old username mapping
        delete usernameToAddress[oldUsername];
        
        // Set new username
        userProfiles[msg.sender].username = _newUsername;
        usernameToAddress[_newUsername] = msg.sender;

        emit UserRegistered(msg.sender, _newUsername);
    }

    // Get user profile by address
    function getUserProfile(address _user) external view returns (
        string memory username,
        uint256 reputation,
        uint256 totalBattles,
        uint256 totalWins,
        bool isRegistered
    ) {
        UserProfile storage profile = userProfiles[_user];
        return (
            profile.username,
            profile.reputation,
            profile.totalBattles,
            profile.totalWins,
            profile.isRegistered
        );
    }

    // Get address by username
    function getAddressByUsername(string memory _username) external view returns (address) {
        return usernameToAddress[_username];
    }

    // Create a new battle
    function createBattle(
        string memory _category,
        uint256 _entryFee,
        string memory _ipfsHash1
    ) external nonReentrant {
        require(msg.sender != address(0), "Invalid creator");
        require(userProfiles[msg.sender].isRegistered, "Must be registered");
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

    function joinBattle(uint256 _battleId, string memory _ipfsHash2) external nonReentrant {
        Battle storage battle = battles[_battleId];
        require(battle.isActive, "Battle not active");
        require(userProfiles[msg.sender].isRegistered, "Must be registered");
        require(battle.creator2 == address(0), "Creator2 already exist");
        require(bytes(battle.ipfsHash2).length == 0, "Clip already submitted");
        require(bytes(_ipfsHash2).length > 0, "Invalid IPFS hash");

        battle.creator2 = msg.sender;
        clashToken.safeTransferFrom(msg.sender, address(this), battle.entryFee);

        battle.ipfsHash2 = _ipfsHash2;
        creatorBattles[msg.sender] = _battleId;

        emit ClipSubmitted(_battleId, msg.sender, _ipfsHash2);
    }

    function vote(uint256 _battleId, address _creator, uint256 _amount) external nonReentrant {
        Battle storage battle = battles[_battleId];
        require(battle.isActive, "Battle not active");
        require(
            block.timestamp < battle.votingEndTime,
            "Voting period ended"
        );
        require(
            _creator == battle.creator1 || _creator == battle.creator2,
            "Invalid creator"
        );
        require(_amount > 0, "Vote amount must be greater than zero");

        clashToken.safeTransferFrom(msg.sender, address(this), _amount);

        votesPerBattle[_battleId][msg.sender] += _amount;
        if (_creator == battle.creator1) {
            battle.votes1 += _amount;
        } else {
            battle.votes2 += _amount;
        }

        emit Voted(_battleId, msg.sender, _creator, _amount);
    }

    function endBattle(uint256 _battleId) external nonReentrant {
        Battle storage battle = battles[_battleId];
        require(battle.isActive, "Battle not active");
        require(
            block.timestamp >= battle.votingEndTime,
            "Voting period not ended"
        );

        // Determine winner
        address winner;
        if (battle.votes1 > battle.votes2) {
            winner = battle.creator1;
        } else if (battle.votes2 > battle.votes1) {
            winner = battle.creator2;
        } else {
            // Tie: Refund entry fees
            clashToken.safeTransfer(battle.creator1, battle.entryFee);
            clashToken.safeTransfer(battle.creator2, battle.entryFee);
            battle.isActive = false;
            creatorBattles[battle.creator1] = 0;
            creatorBattles[battle.creator2] = 0;
            return;
        }

        // Calculate rewards
        uint256 totalEntryFees = battle.entryFee * 2;
        uint256 creatorReward = (totalEntryFees * CREATOR_REWARD_PERCENT) / 100;
        uint256 voterRewardPool = (totalEntryFees * VOTER_REWARD_PERCENT) / 100;
        uint256 protocolFee = (totalEntryFees * PROTOCOL_FEE_PERCENT) / 100;

        // Distribute rewards
        clashToken.safeTransfer(winner, creatorReward);
        clashToken.safeTransfer(treasury, protocolFee);

        // Voter rewards are claimable separately to save gas
        battle.winner = winner;
        battle.isActive = false;
        creatorBattles[battle.creator1] = 0;
        creatorBattles[battle.creator2] = 0;

        emit BattleEnded(_battleId, winner, creatorReward, voterRewardPool);
        emit RewardsDistributed(_battleId, winner, creatorReward);
    }
}
