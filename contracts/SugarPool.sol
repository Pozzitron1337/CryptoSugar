//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./Sugar.sol";
import "./SugarBlock.sol";
import "./SugarDao.sol";

contract SugarPool is Initializable {

    using SafeERC20Upgradeable for Sugar;

    Sugar public sugar;
    SugarBlock public sugarBlock;
    SugarDao public sugarDao;
   
    function initialize(address _sugar, address payable _sugarBlock, address _sugarDao) public initializer {
        sugar = Sugar(_sugar);
        sugarBlock = SugarBlock(_sugarBlock);
        sugarDao = SugarDao(_sugarDao);
    }

    modifier onlySugarDao() {
        require(msg.sender == address(sugarDao), "Sugar: msg.sender is not SugarBlock");
        _;
    }

    function buySugar() public payable returns (uint256 sugarOut) {
        uint256 etherAmount = msg.value;
        sugarOut = getSugarOut(etherAmount, getEtherBalance(), getSugarBalance());
        sugar.safeTransfer(msg.sender, sugarOut);
    }

    function sendHalfEtherBalance(address to) public onlySugarDao {
        
    }

    function sugarPriceInEther() public view returns (uint256) {
        uint256 sugarBalance = getSugarBalance();
        if (sugarBalance > 0) {
            return 10 ** sugar.decimals() * getEtherBalance() / sugarBalance;
        } else {
            return 0;
        }
    }

    function getSugarOut(uint256 etherIn, uint256 etherBalance, uint256 sugarBalance) public view returns (uint256) {
        require(etherIn > 0 && etherBalance > 0 && sugarBalance > 0, "invalid inputs");
        return etherIn * sugarBalance / (etherBalance + etherIn);
    }

    function getEtherBalance() public view returns(uint256) {
        return address(this).balance;
    }
    
    function getSugarBalance() public view returns (uint256) {
        return sugar.balanceOf(address(this));
    }
}
