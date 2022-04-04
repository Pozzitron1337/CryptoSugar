//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./Sugar.sol";
import "./SugarBlock.sol";
import "./SugarPool.sol";


contract SugarDao is Initializable {

    using SafeERC20Upgradeable for Sugar;

    Sugar public sugar;
    SugarBlock public sugarBlock;
    SugarPool public sugarPool;

    ProposalInfo[] public proposalInfo;

    uint256 public votingPeriod;

    mapping(uint256 => uint256) public totalSugarStaked;
    mapping(uint256 => mapping(address => VotePosition)) public votePosition;

    enum ProposalState {
        VOTING,
        EXECUTED,
        NOT_EXECUTED,
        REVERTED
    }
  
    struct ProposalInfo {
        ProposalState state;
        uint256 proposalId;
        bytes functionToCall;
        bytes[] params;
        uint256 proposalStart;
        uint256 reward;
    }

    struct VotePosition {
        uint256 sugarStaked;
        uint256 sugarAvailable;
    }

    modifier onlyAfterVotingPeriod(uint256 proposalId, uint256 extraTime) {
        uint256 currentTime = block.timestamp;
        require(currentTime > proposalInfo[proposalId].proposalStart + votingPeriod + extraTime, "SugarDao: too early to start execution");
        _;
    }
    
    function initialize(address _sugar, address payable _sugarBlock) public initializer {
        require(_sugarBlock != address(0),"SugarDao: invalid _sugarBlock address");
        sugar = Sugar(_sugar);
        sugarBlock = SugarBlock(_sugarBlock);
        votingPeriod = 3 weeks;
    }

    function propose(
        bytes memory functionToCall,
        bytes[] memory params
    ) public returns (uint256) {
        uint256 proposalId = proposalInfo.length;
        uint256 proposalStart = block.timestamp;
        proposalInfo.push(
            ProposalInfo(
                ProposalState.VOTING,
                proposalId, 
                functionToCall, 
                params, 
                proposalStart, 
                0
            )
        );
        return proposalId;
    }

    function vote(
        uint256 proposalId,
        uint256 sugarAmount
    ) public {
        VotePosition storage _votePosition = votePosition[proposalId][msg.sender];
        sugar.safeTransferFrom(msg.sender, address(this), sugarAmount);
        _votePosition.sugarStaked += sugarAmount;
        totalSugarStaked[proposalId] += sugarAmount;
    }

    function execute(uint256 proposalId) public onlyAfterVotingPeriod(proposalId, 0) {
        ProposalInfo storage _proposalInfo = proposalInfo[proposalId];
        require(_proposalInfo.state == ProposalState.VOTING, "SugarDao: proposal is executed");
        uint256 sugarBlockId = sugarBlock.mint(address(this));      // receive sugarBlock NFT
        uint256 sugarMinted = sugarBlock.burn(sugarBlockId);        // burn sugarBlock NFT and receive sugar

        uint256 sugarSendToExecutor = sugarMinted / 2;              // executor will earn 1/2 of minted sugar
        sugar.safeTransfer(msg.sender, sugarSendToExecutor);        // transfer half of minted sugar to executor
        uint256 restSugar = sugarMinted - sugarSendToExecutor;      // rest sugar equal 1/2 of minted sugar

        if (totalSugarStaked[proposalId] >= quorum()) {             // if quorum is reached
            sugarPool.sendHalfEther(msg.sender);                    // transfer half of ether from sugar pool to executor
            _proposalInfo.state = ProposalState.EXECUTED;           // change state of proposal to executed
            _proposalInfo.reward = restSugar;                       // rest 1/2 of minted sugar will be distributed to voters
            
            // execute proposal
        } else {
            _proposalInfo.state = ProposalState.NOT_EXECUTED;       // if quorum is not reached
            uint256 sugarSendToPool = restSugar / 2;                // send 1/2 of rest sugar to sugar pool
            sugar.safeTransfer(address(sugarPool), sugarSendToPool);// transfer 1/2 of rest sugar to sugar pool
            _proposalInfo.reward = restSugar - sugarSendToPool;     // 1/2 of rest sugar will be distributed to voters
        }

    }

    function claimSugar(uint256 proposalId) public onlyAfterVotingPeriod(proposalId, 0) {
        ProposalInfo storage _proposalInfo = proposalInfo[proposalId];
        VotePosition storage _votePosition = votePosition[proposalId][msg.sender];
        require(_proposalInfo.state == ProposalState.EXECUTED || _proposalInfo.state == ProposalState.NOT_EXECUTED, "SugarDao: call execute(proposalId)");
        if (_proposalInfo.state == ProposalState.EXECUTED) {   
            uint256 sugarReward = _proposalInfo.reward * _votePosition.sugarStaked / totalSugarStaked[proposalId];
            uint256 sugarAmountToSend = _votePosition.sugarStaked + sugarReward;
            sugar.safeTransfer(msg.sender, sugarAmountToSend);
            _votePosition.sugarStaked = 0;
        } else {
            uint256 sugarAmountToSend = _votePosition.sugarStaked;
            sugar.safeTransfer(msg.sender, sugarAmountToSend);
            _votePosition.sugarStaked = 0;
        }
    }

    function revertProposal(uint256 proposalId) public onlyAfterVotingPeriod(proposalId, 1 hours){
        ProposalInfo storage _proposalInfo = proposalInfo[proposalId];
        require(_proposalInfo.state == ProposalState.VOTING, "SugarDao: proposal is executed or not executed");
        _proposalInfo.state = ProposalState.REVERTED;
        // send ticket NFT for execution. This ticket NFT can be converted to sugar by some exchange rate
    }

    /**
     * @dev minimal amount of sugar token to execute 
     */
    function quorum() public view returns (uint256) {
        uint256 totalSupply = sugar.totalSupply();
        return totalSupply / 2;
    }

    function proposalLength() public view returns (uint256) {
        return proposalInfo.length;
    }
    
}
