//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/VatLike.sol";

contract EmergencyShutdown is Ownable {

    event MultiSigUpdated(address oldAdd, address newAdd);
    
    modifier auth {
        require(msg.sender == multisig, "EmergencyShutdown/not-authorized");
        _;
    }

    address public vat;
    address public multisig;

    constructor(address _vat, address _multisig) {
        vat = _vat;
        multisig = _multisig;
    }

    function cage() external auth {
        VatLike(vat).cage();
    }

    function setMultiSig(address _multisig) external onlyOwner {
        address oldAdd = multisig;
        multisig = _multisig;
        emit MultiSigUpdated(oldAdd, _multisig);
    }
}
