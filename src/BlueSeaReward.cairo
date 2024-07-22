use core::hash::{Hash, HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin::utils::cryptography::snip12::{StructHash, OffchainMessageHash, SNIP12Metadata};
use starknet::ContractAddress;

const MESSAGE_TYPE_HASH: felt252 =
    0x120ae1bdaf7c1e48349da94bb8dad27351ca115d6605ce345aee02d68d99ec1;

#[derive(Copy, Drop, Hash)]
struct Message {
    recipient: ContractAddress,
    amount: u256,
    nonce: felt252,
    expiry: u64
}

impl StructHashImpl of StructHash<Message> {
    fn hash_struct(self: @Message) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(MESSAGE_TYPE_HASH).update_with(*self).finalize()
    }
}

#[starknet::contract]
mod BlueSeaReward {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::account::dual_account::{DualCaseAccount, DualCaseAccountABI};
    use openzeppelin::token::erc20::dual20::{DualCaseERC20, DualCaseERC20Trait};
    use openzeppelin::token::erc20::ERC20Component::{ERC20MetadataImpl, InternalImpl};
    use openzeppelin::utils::cryptography::nonces::NoncesComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::ClassHash;
    use starknet::ContractAddress;

    use super::{Message, OffchainMessageHash, SNIP12Metadata};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
    impl NoncesInternalImpl = NoncesComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,

        reward_token: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    /// Required for hash computation.
    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'BlueSeaReward'
        }
        fn version() -> felt252 {
            'v1'
        }
    }

    #[external(v0)]
    fn claim_with_signature(
        ref self: ContractState,
        signer: ContractAddress,
        amount: u256,
        nonce: felt252,
        expiry: u64,
        signature: Array<felt252>
    ) {
        assert(starknet::get_block_timestamp() <= expiry, 'Expired signature');
        let recipient = starknet::get_caller_address();

        // Check and increase nonce
        self.nonces.use_checked_nonce(signer, nonce);

        // Build hash for calling `is_valid_signature`
        let message = Message { recipient, amount, nonce, expiry };
        let hash = message.get_message_hash(signer);

        let is_valid_signature_felt = DualCaseAccount { contract_address: signer }
            .is_valid_signature(hash, signature);

        // Check either 'VALID' or True for backwards compatibility
        let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
            || is_valid_signature_felt == 1;
        assert(is_valid_signature, 'Invalid signature');

        // // Transfer tokens
        let token = DualCaseERC20 { contract_address: self.reward_token.read() };
        token.transfer_from(starknet::get_contract_address(), recipient, amount);
    }
}