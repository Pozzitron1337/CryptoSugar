//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./Sugar.sol";
import "./SugarDao.sol";
import "./SugarPool.sol";

/**
 * @notice SugarBlock is NFT that can be minted by mining using proof-of-work or purchasing, depending on current cost of target value
 */
contract SugarBlock is Initializable, ERC721EnumerableUpgradeable {

    uint256 public constant MINIMAL_ETH_COST = 1 ether;

    uint256 public constant MAXIMAL_ETH_COST = 1_000_000 ether;

    uint256 public constant MINIMAL_ETH_COST_DIFFERENCE = 1000 ether;

    uint256 public constant MINIMAL_TARGET_VALUE = 2 ** 50;

    uint256 public constant MAXIMAL_TARGET_VALUE = type(uint256).max / 2;
    
    /**
     * @dev address of SGR token
     */
    Sugar public sugar;

    /**
     * @dev address of sugarDao
     */
    SugarDao public sugarDao;

    /**
     * @dev address of sugar pool
     */
    SugarPool public sugarPool;

    /**
     * @dev the amount of SGR that will be mint to burner of sugarBlock
     */
    uint256 public sugarInSugarBlock;

    /** Mining variables */

    uint256 public targetValue;
    uint256 public entropyNonce;

    uint256 public maxEthCost;
    uint256 public minEthCost;

    uint256 public maxTargetValue;
    uint256 public minTargetValue;
   
    /** SugarBlocks info */

    uint256 public totalSugarBlocksMined;

    modifier onlySugarDao {
        require(msg.sender == address(sugarDao), "msg.sender is not sugarDao");
        _;
    }

    function initialize(address _sugar, address _sugarDao) public initializer {
        __ERC721_init("SugarBlocks", "SB");
        __ERC721Enumerable_init_unchained();
        require(_sugar != address(0), "SugarBlock: invalid sugar address");
        require(_sugarDao != address(0), "SugarBlock: invalid sugarDao address");
        sugar = Sugar(_sugar);
        sugarDao = SugarDao(_sugarDao);
        sugarInSugarBlock = 100_000_000; // 100 SGR 
        targetValue = type(uint256).max;
        entropyNonce = 0;
        maxEthCost = 1000 ether;
        minEthCost = 1 ether;
        maxTargetValue = type(uint256).max / 2;
        minTargetValue = 2 ** 50;
    }

    function setBoundsToEthCost(uint256 _minEthCost, uint256 _maxEthCost) public onlySugarDao {
        require(_minEthCost >= MINIMAL_ETH_COST, "SugarBlock: too low _minEthCost");
        require(_maxEthCost <= MAXIMAL_ETH_COST, "SugarBlock: too hight _maxEthCost");
        require(_minEthCost < _maxEthCost, "SugarBlock: invalid bounds of EthCost");
        require(_maxEthCost - _minEthCost >= MINIMAL_ETH_COST_DIFFERENCE, "SugarBlock: difference between max and min should be 1000");
        minEthCost = _minEthCost;
        maxEthCost = _maxEthCost;
    }

    function setBoundsToTargetValue(uint256 _minTargetValue, uint256 _maxTargetValue) public onlySugarDao {
        require(_minTargetValue >= MINIMAL_TARGET_VALUE, "SugarBlock: too low _minTargetValue");
        require(_maxTargetValue <= MAXIMAL_TARGET_VALUE, "SugarBlock: too hight _maxTargetValue");
        require(_minTargetValue < _maxTargetValue, "SugarBlock: Invalid bounds of targetValue");
        minTargetValue = _minTargetValue;
        maxTargetValue = _maxTargetValue;
    }

    function increaseTargetValue() public onlySugarDao {
        if(targetValue < type(uint256).max / 2){
            targetValue *= 2;
        }
    }

    /**
     * @dev mine sugar block with mining effort.
     * @param sweetNonce - number, that shoud fit to inequality SHA3(concat(sweetNonce, msg.sender, entropyNonce)) < targetValue
     */
    function hardMine(uint256 sweetNonce) public {
        uint256 output = uint256(keccak256(abi.encode(sweetNonce, uint256(uint160(msg.sender)), entropyNonce))); // Target function SHA3(nonce XOR address of sender of transaction)
        require(output <= targetValue, "SugarBlock: failed to mine: output of target function not less than targetValue");
        if (minTargetValue < (targetValue / 2)) {
            targetValue /= 2;
        }
        unchecked {
            entropyNonce++;
        }
        mintInternal(msg.sender);
    }

    /**
     * @dev mine sugar block with no efforts. Just send more or equal costOfTargetValue() ether and it mine the block to msg.sender
     */
    function easyMine() public payable {
        uint256 cost = costOfTargetValue();
        require(msg.value >= cost, "SugarBlock: too low native token amount to buy");
        if(msg.value > cost) {
            (bool sentRest, ) = payable(msg.sender).call{
                value: msg.value - cost
            }("");
            require(sentRest,"Failed to send to msg.sender the rest");
        }
        (bool sentToPool, ) = payable(sugarPool).call{
            value: cost
        }("");
        require(sentToPool, "Failed to send to sugarPool costOfTarget");
        mintInternal(msg.sender);
    }

    function mint(address to) public onlySugarDao returns (uint256) {
        return mintInternal(to);
    }

    /**
     * @dev destroy the sugar block and mints sugar ERC20 token to burner.
     * @dev return the amount of minted sugar ERC20 token
     * @param sugarBlockId id of sugar block. Callet should be the owner if `sugarBlockId`
     */
    function burn(uint256 sugarBlockId) public returns (uint256) {
        require(msg.sender == ownerOf(sugarBlockId), "SugarBlock: msg.sender is not owner of this sugarBlockId");
        _burn(sugarBlockId);
        sugar.mint(msg.sender, sugarInSugarBlock);
        return sugarInSugarBlock;
    }

    /**
     * @dev mints sugar block to `to`
     */
    function mintInternal(address to) internal returns (uint256) {
        uint256 sugarBlockId = totalSugarBlocksMined;
        _mint(to, sugarBlockId);
        totalSugarBlocksMined++;
        return sugarBlockId;
    }

    /**
     * @dev returns the owner of `sugarBlockId` 
     */
    function ownerOf(uint256 sugarBlockId) public view override(ERC721Upgradeable,IERC721Upgradeable) returns (address) {
        return ERC721Upgradeable.ownerOf(sugarBlockId);
    }

    /**
     * @dev returns the sugarBlockId of `owner` by `index` of array 
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        return super.tokenOfOwnerByIndex(owner, index);
    }

    /**
     * @dev returns the total supply of sugar blocks
     */
    function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    function costOfTargetValue() public view returns (uint256) {
        return calculateCostOfTargetValue(targetValue);
    }

    /** @notice proof that ethCost is defined by implemented formula
     *
     *    | maxEthCost = a * minTargetValue + b
     *    | minEthCost = a * maxTargetValue + b
     *
     *=>  a = (maxEthCost - minEthCost) / (minTargetValue - maxTargetValue)
     *    b = maxEthCost - (maxEthCost - minEthCost) / (minTargetValue - maxTargetValue) * minTargetValue
     *    b = maxEthCost + (maxEthCost - minEthCost) / (maxTargetValue - minTargetValue) * minTargetValue
     *
     *=> ethCost = (maxEthCost - minEthCost) / (minTargetValue - maxTargetValue) * targetValue + maxEthCost + (maxEthCost - minEthCost) / (maxTargetValue - minTargetValue) * minTargetValue = 
     *           = (maxEthCost - minEthCost) / (minTargetValue - maxTargetValue) * (targetValue - minTargetValue) + maxEthCost = 
     *           = maxEthCost - (maxEthCost - minEthCost) / (maxTargetValue - minTargetValue ) * (targetValue - minTargetValue)
     */
    function calculateCostOfTargetValue(uint256 _targetValue) public view returns (uint256 cost) {
        require(minTargetValue <= _targetValue && _targetValue <= maxTargetValue, "SugarBlock: invalid targetValue");
        cost = maxEthCost - ((maxEthCost - minEthCost) * (_targetValue - minTargetValue) / (minTargetValue - maxTargetValue));
    }

    receive() external payable {}
    
}
