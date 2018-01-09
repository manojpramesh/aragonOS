pragma solidity ^0.4.0;

import "../apps/App.sol";
import "./AbstractENS.sol";
import "./PublicResolver.sol";
import "../common/Initializable.sol";


contract ENSSubdomainRegistrarConstants {
    bytes32 constant public ETH_TLD_NODE = keccak256(bytes32(0), keccak256("eth"));
    bytes32 constant public PUBLIC_RESOLVER_NODE = keccak256(ETH_TLD_NODE, keccak256("resolver"));
}


contract ENSSubdomainRegistrar is App, Initializable, ENSSubdomainRegistrarConstants {
    bytes32 constant public CREATE_NAME_ROLE = bytes32(1);
    bytes32 constant public DELETE_NAME_ROLE = bytes32(2);
    bytes32 constant public POINT_ROOTNODE_ROLE = bytes32(3);

    AbstractENS public ens;
    bytes32 public rootNode;

    event NewName(bytes32 indexed node, bytes32 indexed label);
    event DeleteName(bytes32 indexed node, bytes32 indexed label);

    function initialize(AbstractENS _ens, bytes32 _rootNode) onlyInit public {
        initialized();

        // We need ownership to create subnodes
        require(_ens.owner(_rootNode) == address(this));

        ens = _ens;
        rootNode = _rootNode;
    }

    function createName(bytes32 _label, address _owner) auth(CREATE_NAME_ROLE) external returns (bytes32 node) {
        return _createName(_label, _owner);
    }

    function createNameAndPoint(bytes32 _label, address _target) auth(CREATE_NAME_ROLE) external returns (bytes32 node) {
        node = _createName(_label, this);
        _pointToResolverAndResolve(node, _target);
    }

    function deleteName(bytes32 _label) auth(DELETE_NAME_ROLE) external {
        bytes32 node = keccak256(rootNode, _label);

        if (ens.owner(node) != address(this)) // needs to reclaim ownership so it can set resolver
            ens.setSubnodeOwner(rootNode, _label, this);

        ens.setResolver(node, address(0)); // remove resolver so it ends resolving
        ens.setOwner(node, address(0));

        DeleteName(node, _label);
    }

    function pointRootNode(address _target) auth(POINT_ROOTNODE_ROLE) external {
        _pointToResolverAndResolve(rootNode, _target);
    }

    function _createName(bytes32 _label, address _owner) internal returns (bytes32 node) {
        node = keccak256(rootNode, _label);
        require(ens.owner(node) == address(0)); // avoid name reset

        ens.setSubnodeOwner(rootNode, _label, _owner);

        NewName(node, _label);
    }

    function _pointToResolverAndResolve(bytes32 _node, address _target) internal {
        address publicResolver = getAddr(PUBLIC_RESOLVER_NODE);
        ens.setResolver(_node, publicResolver);

        PublicResolver(publicResolver).setAddr(_node, _target);
    }

    function getAddr(bytes32 node) internal view returns (address) {
        address resolver = ens.resolver(node);
        return PublicResolver(resolver).addr(node);
    }
}
