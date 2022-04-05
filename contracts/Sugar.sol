//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./SugarBlock.sol";

/** 
 * Sugar is token with ERC20 interface.
 * http://www.bolshoyvopros.ru/questions/3264373-skolko-krupinok-sahara-v-odnom-kologramme-sahara.html
 * let in 1 kilogram of sugar with cristall mass of 0.0005 gramm contains: 1000/0.0005 = 2_000_000 pieces 
 * let 2_000_000 SGR represents 1 kilogramm of sugar. Then decimals of SGR equal 6
 */
contract Sugar is Initializable, ERC20Upgradeable {

    SugarBlock public sugarBlock;
   
    function initialize(address payable _sugarBlock) public initializer {
        __ERC20_init("Sugar token", "SGR");
        require(_sugarBlock != address(0),"Sugar: invalid _sugarBlock address");
        sugarBlock = SugarBlock(_sugarBlock);
    }

    modifier onlySugarBlock() {
        require(msg.sender == address(sugarBlock), "Sugar: msg.sender is not SugarBlock");
        _;
    }
    
    /**
     * @dev mints sugar from sugar block
     */
    function mint(address account, uint256 sugarAmount) public onlySugarBlock {
        _mint(account, sugarAmount);
    }

    function decimals() public pure override returns(uint8) {
        return 6;
    }
    
}
