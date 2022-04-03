//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./Sugar.sol";
import "./SugarDao.sol";

contract SugarBlock is Initializable, ERC721EnumerableUpgradeable {

    /**
     * @dev address of SGR token
     */
    Sugar public sugar;

    SugarDao public sugarDao;

    /**
     * @dev the amount of SGR that will be mint to burner of sugarBlock
     */
    uint256 sugarInSugarBlock;

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
        maxEthCost = 10 ether;
        minEthCost = 10 gwei;
        maxTargetValue = type(uint256).max / 2;
        minTargetValue = 2 ** 50;
    }

    function setBoundsToEthCost(uint256 _minEthCost, uint256 _maxEthCost) public onlySugarDao {
        require(_minEthCost >= 1 gwei, "SugarBlock: too low _minEthCost");
        require(_maxEthCost <= 100 ether, "SugarBlock: too hight _maxEthCost");
        require(_minEthCost < _maxEthCost, "SugarBlock: invalid bounds of EthCost");
        minEthCost = _minEthCost;
        maxEthCost = _maxEthCost;
    }

    function setBoundsToTargetValue(uint256 _minTargetValue, uint256 _maxTargetValue) public onlySugarDao {
        require(_minTargetValue >= 2 ** 50, "SugarBlock: too low _minTargetValue");
        require(_maxTargetValue <= type(uint256).max / 2, "SugarBlock: too hight _maxTargetValue");
        require(_minTargetValue < _maxTargetValue, "SugarBlock: Invalid bounds of targetValue");
        minTargetValue = _minTargetValue;
        maxTargetValue = _maxTargetValue;
    }

    /**
     * @dev mine sugar block with mining effort.
     * @param sweetNonce - number, that shoud fit to inequality SHA3(sweetNonce XOR msg.sender XOR entropyNonce) < targetValue
     */
    function hardMine(uint256 sweetNonce) public {
        uint256 output = uint256(keccak256(abi.encode(sweetNonce ^ uint256(uint160(msg.sender)) ^ entropyNonce))); // Target function SHA3(nonce XOR address of sender of transaction)
        require(output <= targetValue, "SugarBlock: failed to mine: output of target function not less than targetValue");
        if (minTargetValue < (targetValue / 2)) {
            targetValue /= 2;
        }
        entropyNonce++;
        mintInternal(msg.sender);
    }

    /**
     * @dev mine sugar block with no efforts. Just send more or equal costOfTargetValue() ether and it mine the block to msg.sender
     */
    function easyMine() public payable {
        uint256 cost = costOfTargetValue();
        require(msg.value >= cost, "SugarBlock: too low native token amount to buy");
        if(msg.value > cost) {
            (bool sent, ) = payable(msg.sender).call{
                value: msg.value - cost
            }("");
            require(sent,"Failed to send to msg.sender the rest");
        }
        mintInternal(msg.sender);
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

    function mint(address to) public onlySugarDao returns (uint256) {
        return mintInternal(to);
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
