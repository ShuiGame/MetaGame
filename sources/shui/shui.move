module shui_module::shui {
    use std::option::{Self};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::url;
    use shui_module::race::{Self};
    use shui_module::level::{Self};
    use shui_module::gift::{Self};
    use shui_module::avatar::{Self};

    #[test_only]
    use sui::test_scenario::{
        Scenario, ctx
    };

    friend shui_module::airdrop;   
    friend shui_module::swap;
    friend shui_module::founder_team_reserve;
    friend shui_module::mission;

    const TYPE_FOUNDER:u64 = 0;
    const TYPE_CO_FOUNDER:u64 = 1;
    const TYPE_ENGINE_TEAM:u64 = 2;
    const TYPE_TECH_TEAM:u64 = 3;
    const TYPE_PROMOTE_TEAM:u64 = 4;
    const TYPE_PARTNER:u64 = 5;
    const TYPE_ANGLE_INVEST:u64 = 6;
    const TYPE_PUBLIC:u64 = 7;
    const TYPE_META_VIP:u64 = 8;
    const SHUI_ICON_URL:vector<u8> = b"https://nftstorage.link/ipfs/bafybeieqqos2upvmmxzmauv6cf53ddegpjc5zkrvbpriz7iajamcxikv4y";

    const ERR_CHARACTOR_CREATED:u64 = 0x001;
    const ERR_BINDED:u64 = 0x002;
    const ERR_UNBINDED:u64 = 0x003;
    const ERR_NO_PERMISSION:u64 = 0x004;
    const ERR_NOT_IN_WHITELIST:u64 = 0x005;
    const EXCEED_SWAP_LIMIT:u64 = 0x006;
    const ERR_BALANCE_NOT_ENOUGH:u64 = 0x007;
    const ERR_ALREADY_BIND:u64 = 0x008;
    const ERR_SWAP_MIN_ONE_SUI:u64 = 0x009;
    const ERR_INVALID_TYPE:u64 = 0x010;
    const ERR_META_HAS_CREATED:u64 = 0x011;

    const TOTAL_SUPPLY: u64 = 2_100_000_000;
    const FOUNDATION_RESERVE:u64 = 50_000_000;
    const DAO_RESERVE:u64 = 50_000_000;
    const GAME_RESERVE:u64 = 1_000_000_000;
    const FOUNDER_TEAM_RESERVE:u64 = 21_000_000;
    const MISSION_RESERVE:u64 = 239_000_000;
    const AMOUNT_DECIMAL:u64 = 1_000_000_000;
    const AIRDROP_AMOUNT:u64 = 390_000_000;
    const SWAP_AMOUNT:u64 = 379_000_000;

    struct SHUI has drop {}

    struct Global has key {
        id: UID,
        supply: u64,

        // split by balance
        balance_SUI: Balance<SUI>,
        balance_SHUI: Balance<SHUI>,
        creator: address,
    }

    struct Inscription has key {
        id:UID,
        name: string::String,
        gender: string::String,
        avatar: avatar::Avatar,
        race: race::Race,
        level: level::Level,
        gift: gift::Gift,
    }

    fun init(witness: SHUI, ctx: &mut TxContext) {
        let (adminCap, metadata) = coin::create_currency(witness, 
            9,
            b"SHUI",
            b"SHUI",
            b"SHUI token",
            option::some(url::new_unsafe_from_bytes(SHUI_ICON_URL)),
            ctx);
        transfer::public_freeze_object(metadata);
        let global = Global {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            supply: TOTAL_SUPPLY,
            balance_SUI: balance::zero(),
            balance_SHUI: balance::zero(),
        };
        let total_shui = mint(&mut adminCap, TOTAL_SUPPLY * AMOUNT_DECIMAL, ctx);
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
        let balance = coin::into_balance<SHUI>(
            total_shui
        );
        balance::join(&mut global.balance_SHUI, balance);

        // transfer ther reserve shui to dao and foundation account;
        transfer_to_reserve(&mut global, @game_reserve_wallet, GAME_RESERVE * AMOUNT_DECIMAL, ctx);
        transfer_to_reserve(&mut global, @dao_reserve_wallet, DAO_RESERVE * AMOUNT_DECIMAL, ctx);
        transfer::share_object(global);
    }

    #[test_only]
    public fun init_for_test(scenario: &mut Scenario) {
        let witness = SHUI{};
        init(witness, ctx(scenario));
    }

    public fun new_empty_charactor(ctx: &mut TxContext):Inscription {
        Inscription{
            id:object::new(ctx),
            name:string::utf8(b""),
            gender: string::utf8(b""),
            avatar: avatar::none(),
            race: race::none(),
            level: level::new_level(),
            gift: gift::none(),
        }
    }

    public entry fun change_gift(charactor:&mut Inscription, gift:string::String) {
        charactor.gift = gift::new_gift(gift);
    }

    fun mint(treasuryCap:&mut TreasuryCap<SHUI>, amount:u64, ctx:&mut TxContext) : Coin<SHUI>{
        coin::mint(treasuryCap, amount, ctx)
    }

    fun transfer_to_reserve(global: &mut Global, recepient:address, amount:u64, ctx:&mut TxContext) {
        let airdrop_balance = balance::split(&mut global.balance_SHUI, amount);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, recepient);
    }

    public entry fun burn(treasury: &mut TreasuryCap<SHUI>, coin: Coin<SHUI>) {
        coin::burn(treasury, coin);
    }

    public entry fun withdraw_sui(global: &mut Global, amount:u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        let airdrop_balance = balance::split(&mut global.balance_SUI, amount);
        let sui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(sui, tx_context::sender(ctx));
    }

    public entry fun withdraw_shui(global: &mut Global, amount:u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        let airdrop_balance = balance::split(&mut global.balance_SHUI, amount);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, tx_context::sender(ctx));
    }

    public(friend) fun extract_airdrop_balance(global: &mut Global, ctx: &mut TxContext) : balance::Balance<SHUI> {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        balance::split(&mut global.balance_SHUI, AIRDROP_AMOUNT * AMOUNT_DECIMAL)
    }

    // todo: only once call
    public(friend) fun extract_swap_balance(global: &mut Global, ctx: &mut TxContext) : balance::Balance<SHUI> {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        balance::split(&mut global.balance_SHUI, SWAP_AMOUNT * AMOUNT_DECIMAL)
    }

    public(friend) fun extract_founder_reserve_balance(global: &mut Global, ctx: &mut TxContext) : balance::Balance<SHUI> {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        balance::split(&mut global.balance_SHUI, FOUNDER_TEAM_RESERVE * AMOUNT_DECIMAL)
    }

    public(friend) fun extract_mission_reserve_balance(global: &mut Global, ctx: &mut TxContext) : balance::Balance<SHUI> {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        balance::split(&mut global.balance_SHUI, MISSION_RESERVE * AMOUNT_DECIMAL)
    }
}