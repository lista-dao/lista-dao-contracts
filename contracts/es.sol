//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/VatLike.sol";

contract EmergencyShutdown is Ownable {

    event MultiSigUpdated(address oldAdd, address newAdd);
    event EmergencySwitchHubUpdated(address oldAdd, address newAdd);
    event Paused(address account);
    event Unpaused(address account);
    
    modifier auth {
        require(
            msg.sender == emergencySwitchHub || msg.sender == mutliSig,
            "EmergencyShutdown/not-authorized"
        );
        _;
    }

    address public vat;
    address public mutliSig;
    address public emergencySwitchHub;

    constructor(address _vat, address _multiSig, address _emergencySwitchHub) {
        require(
            _vat != address(0) && 
            _multiSig != address(0) &&
            _emergencySwitchHub != address(0),
            "EmergencyShutdown/zero-address-provided"
        );
        vat = _vat;
        mutliSig = _multiSig;
        emergencySwitchHub = _emergencySwitchHub;
    }

    /// @dev legacy functions for compatibility with existing emergency shutdown
    function cage() external auth {
        VatLike(vat).cage();
    }

    /// @dev legacy functions for compatibility with existing emergency shutdown
    function uncage() external auth {
        VatLike(vat).uncage();
    }

    function setMultiSig(address _multiSig) external onlyOwner {
        address oldMultiSig = mutliSig;
        mutliSig = _multiSig;
        emit MultiSigUpdated(oldMultiSig, _multiSig);
    }

    /// @dev supports EmergencySwitchHub contract
    function pause() external auth {
        VatLike(vat).cage();
        emit Paused(msg.sender);
    }
    
    /// @dev supports EmergencySwitchHub contract
    function unpause() external auth {
        VatLike(vat).uncage();
        emit Unpaused(msg.sender);
    }

    /// @dev supports EmergencySwitchHub contract
    function paused() external view returns (bool) {
        return VatLike(vat).live() == 0;
    }

    function setEmergencySwitchHub(address _emergencySwitchHub) external onlyOwner {
        address oldHub = emergencySwitchHub;
        emergencySwitchHub = _emergencySwitchHub;
        emit EmergencySwitchHubUpdated(oldHub, _emergencySwitchHub);
    }
}
