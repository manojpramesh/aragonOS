pragma solidity 0.4.18;

import "./DelegateScript.sol";

// Inspired by: https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol


contract DeployDelegateScript is DelegateScript {
    uint256 constant internal SCRIPT_START_LOCATION = 4;

    mapping (bytes32 => address) cache;

    /**
    * @notice Executes script by delegatecall into a deployed contract (exec() function)
    * @param script [ specId (uint32 = 3) ][ contractInitcode (bytecode) ]
    * @param input ABI encoded call to be made to contract (if empty executes default exec() function)
    * @param blacklist If any address is passed, will revert.
    * @param input ABI encoded call to be made to contract
    * @return Call return data
    */
    function execScript(bytes script, bytes input, address[] blacklist) external returns (bytes) {
        require(blacklist.length == 0); // dont have ability to control bans, so fail.

        bytes32 id = keccak256(script);
        address deployed;
        if (!isCached(script)) {
            deployed = deploy(script);
            cache[id] = deployed;
        } else {
            deployed = cache[id];
        }

        return DelegateScript.delegate(deployed, input);
    }

    function getScriptActionsCount(bytes script) public pure returns (uint256) {
        return 1;
    }

    function getScriptAction(bytes, uint256) public pure returns (address, bytes) {
        return (address(0), new bytes(0));
    }

    /**
    * @dev Deploys contract byte code to network
    */
    function deploy(bytes script) internal returns (address addr) {
        assembly {
            // 0x24 = 0x20 (length) + 0x04 (spec id uint32)
            // Length of code is 4 bytes less than total script size
            addr := create(0, add(script, 0x24), sub(mload(script), 0x04))
            switch iszero(extcodesize(addr))
            case 1 { revert(0, 0) } // throw if contract failed to deploy
        }
    }

    function isCached(bytes memory script) internal returns (bool) {
        return cache[keccak256(script)] != address(0);
    }
}
