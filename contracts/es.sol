//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/VatLike.sol";

contract EmergencyShutdown is Ownable {

    event MultiSigUpdated(address oldAdd, address newAdd);
    
    modifier auth {
        require(msg.sender == emergencySwitchHub, "EmergencyShutdown/not-authorized");
        _;
    }

    address public vat;
    address public emergencySwitchHub;

    constructor(address _vat, address _emergencySwitchHub) {
        vat = _vat;
        emergencySwitchHub = _emergencySwitchHub;
    }

    function pause() external auth {
        VatLike(vat).cage();
    }
    
    function unpause() external auth {
        VatLike(vat).uncage();
    }

    function paused() external view returns (bool) {
        return VatLike(vat).live() == 0;
    }

    function setEmergencySwitchHub(address _emergencySwitchHub) external onlyOwner {
        address oldAdd = emergencySwitchHub;
        emergencySwitchHub = _emergencySwitchHub;
        emit MultiSigUpdated(oldAdd, _emergencySwitchHub);
    }
}
