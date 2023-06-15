module hello_world::shui {
    use std::option::{Self, Option};
    use sui::coin::{Self, Coin, TreasuryCap, destroy_zero};
    use sui::transfer;
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use std::vector::{Self};
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::pay;
    use hello_world::race::{Self};
    use hello_world::level::{Self};
    use hello_world::gift::{Self};
    use hello_world::avatar::{Self};
    use sui::table::{Self, Table};

    const TYPE_FOUNDER:u8 = 0;
    const TYPE_CO_FOUNDER:u8 = 1;
    const TYPE_ENGINE_TEAM:u8 = 2;
    const TYPE_TECH_TEAM:u8 = 3;
    const TYPE_PROMOTE_TEAM:u8 = 4;
    const TYPE_PARTNER:u8 = 5;

    const TYPE_IDO:u8 = 6;
    const TYPE_AIRDROP:u8 = 7;
    const TYPE_PUBLIC:u8 = 8;

    const ERR_CHARACTOR_CREATED:u64 = 0x001;
    const ERR_BINDED:u64 = 0x002;
    const ERR_UNBINDED:u64 = 0x003;
    const ERR_NO_PERMISSION:u64 = 0x004;
    const ERR_NOT_IN_WHITELIST:u64 = 0x005;
    const EXCEED_SWAP_LIMIT:u64 = 0x006;
    const ERR_BALANCE_NOT_ENOUGH:u64 = 0x007;

    const CO_FOUNDER_PER_RESERVE:u64 = 3_000_000;
    const FOUNDER_PER_RESERVE:u64 = 4_000_000;
    const ENGINE_TEAM_PER_RESERVE:u64 = 5_000_000;
    const TECH_TEAM_PER_RESERVE:u64 = 500_000;
    const PROMOTE_TEAM_PER_RESERVE:u64 = 400_000;
    const PARTNER_PER_RESERVE:u64 = 350_000;

    const TOTAL_SUPPLY: u64 = 2_100_000_000;
    const AIRDROP_SUPPLY:u64 = 500_000_000;
    const GAME_GAME_SUPPLY:u64 = 1_000_000_000;
    const GOLD_RESERVE_SUPPLY:u64 = 300_000_000;
    const EXCHANGE_SUPPLY:u64 = 100_000_000;
    const FOUNDATION_SUPPLY:u64 = 100_000_000;
    const DAO_SUPPLY:u64 = 100_000_000;

    const AMOUNT_PER_IDO_SWAP_LIMIT:u64 = 100_000;
    const AMOUNT_PER_AIRDROP_SWAP_LIMIT:u64 = 10_000;

    const IDO_SWAP_RATIO:u64 = 250;
    const AIRDROP_SWAP_RATIO:u64 = 250;
    const PUBLIC_SWAP_RATIO:u64 = 100;

    struct SHUI has drop {}
    struct Global has key {
        id: UID,
        supply: u64,
        balance_SUI: Balance<SUI>,
        balance_SHUI: Balance<SHUI>,
        creator: address,
        founder: address,
        co_founder: address,
        engine_team: address,
        tech_whitelist: Table<address, u64>,
        promote_whitelist: Table<address, u64>,
        partner_whitelist: Table<address, u64>,

        ido_whitelist: Table<address, u64>,
        airdrop_whitelist: Table<address, u64>,

        founder_reserve_left: u16,
        co_founder_reserve_left: u16,
        engine_team_reserve_left: u16,
        tech_team_reserve_left:u16,
        promote_team_reserve_left:u16,
        partner_team_reserve_left:u16,
        
        ido_swap_left:u16,
        airdrop_swap_left:u16,
    }

    struct MetaIdentify has key, store {
        // preserve 0-20000 for airdrop
        id:UID,

        // changeto ID
        metaId:ID,
        name:string::String,
        charactor: Option<Inscription>,
        bind:Option<Bind>,
        // wallet:address // is it necessay??
    }

    struct Inscription has store {
        name: string::String,
        gender: string::String,
        avatar: avatar::Avatar,
        race: race::Race,
        level: level::Level,
        gift: gift::Gift,
    }

    struct Bind has key, store {
        id:UID,
        status:bool,
        phone:string::String
    }

    fun init(witness: SHUI, ctx: &mut TxContext) {
        let (adminCap, metadata) = coin::create_currency(witness, 
            6,
            b"shui",
            b"shui",
            b"desc",
            option::none(), 
            ctx);
        transfer::public_freeze_object(metadata);
        let global = Global {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            founder: @founder,
            co_founder: @co_founder,
            engine_team: @engine_team,
            supply: TOTAL_SUPPLY,
            balance_SUI: balance::zero(),
            balance_SHUI: balance::zero(),

            partner_whitelist: table::new<address, u64>(ctx),
            tech_whitelist: table::new<address, u64>(ctx),
            promote_whitelist:  table::new<address, u64>(ctx),
            ido_whitelist: table::new<address, u64>(ctx),
            airdrop_whitelist: table::new<address, u64>(ctx),

            co_founder_reserve_left: 1,
            founder_reserve_left: 1,
            engine_team_reserve_left: 1,
            tech_team_reserve_left: 15,
            promote_team_reserve_left: 10,
            partner_team_reserve_left: 10,

            ido_swap_left:0,
            airdrop_swap_left:0,
        };
        let total_shui = mint(&mut adminCap, TOTAL_SUPPLY, ctx);
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
        let balance = coin::into_balance<SHUI>(
            total_shui
        );

        balance::join(&mut global.balance_SHUI, balance);
        transfer::share_object(global);
    }

    public fun createMetaIdentify(name:string::String, ctx: &mut TxContext) : MetaIdentify{
        // exist judgement
        // bind judgement
        let obj_id = object::new(ctx); 

        // tbd
        let game_id = object::uid_to_inner(&obj_id);
        MetaIdentify {
            id:obj_id,
            metaId:game_id,
            name:name,
            charactor:option::none(),
            bind:option::none(),
        }
    }

    fun createCharactor(
        identity:&mut MetaIdentify,
        name: string::String,
        gender: string::String,
        avatar: avatar::Avatar,
        race: race::Race,
        gift: gift::Gift,
        _: &mut TxContext) {
        assert!(!option::is_some(&identity.charactor), ERR_CHARACTOR_CREATED);
        let new_cha = Inscription{
            name:name,
            gender: gender,
            avatar: avatar,
            race: race,
            level: level::new_level(),
            gift: gift,
        };
        option::fill(&mut identity.charactor, new_cha);
    }

    public fun mint(treasuryCap:&mut TreasuryCap<SHUI>, amount:u64, ctx:&mut TxContext) : Coin<SHUI>{
        coin::mint(treasuryCap, amount, ctx)
    }

    public entry fun ido_swap<T> (global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let ratio = IDO_SWAP_RATIO;
        let limit = AMOUNT_PER_IDO_SWAP_LIMIT;
        let recepient = tx_context::sender(ctx);
        assert!(table::contains(&global.ido_whitelist, recepient), ERR_NOT_IN_WHITELIST);
        assert!(has_swap_amount(&mut global.ido_whitelist, sui_pay_amount * ratio, recepient), EXCEED_SWAP_LIMIT);
        swap_internal<T>(global, sui_pay_amount, coins, ratio, limit, ctx);
        record_swaped_amount(&mut global.ido_whitelist, sui_pay_amount * ratio, recepient);
    }

    public entry fun airdrop_swap<T> (global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let ratio = AIRDROP_SWAP_RATIO;
        let limit = AMOUNT_PER_AIRDROP_SWAP_LIMIT;
        let recepient = tx_context::sender(ctx);
        assert!(table::contains(&global.airdrop_whitelist, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
        assert!(has_swap_amount(&mut global.airdrop_whitelist, sui_pay_amount * ratio, recepient), EXCEED_SWAP_LIMIT);
        swap_internal<T>(global, sui_pay_amount, coins, ratio, limit, ctx);
        record_swaped_amount(&mut global.airdrop_whitelist, sui_pay_amount * ratio, recepient);
    }

    public entry fun public_swap<T> (global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ctx:&mut TxContext) {
        let ratio = PUBLIC_SWAP_RATIO;
        let limit = TOTAL_SUPPLY;
        swap_internal<T>(global, sui_pay_amount, coins, ratio, limit, ctx);
    }

    public fun swap_internal<T> (global: &mut Global, sui_pay_amount:u64, coins:vector<Coin<SUI>>, ratio:u64, limit:u64, ctx:&mut TxContext) {
        let account = tx_context::sender(ctx);
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);
        assert!(coin::value(&merged_coin) <= limit, EXCEED_SWAP_LIMIT);

        let balance = coin::into_balance<SUI>(
            coin::split<SUI>(&mut merged_coin, sui_pay_amount, ctx)
        );

        balance::join(&mut global.balance_SUI, balance);

        // transfer remain to account
        if (coin::value(&merged_coin) > 0) {
            transfer::public_transfer(merged_coin, account)
        } else {
            destroy_zero(merged_coin)
        };

        // transfer SHUI to account
        let shui_amount:u64 = sui_pay_amount * ratio;
        let airdrop_balance = balance::split(&mut global.balance_SHUI, shui_amount);
        let shui = coin::from_balance(airdrop_balance, ctx);

        transfer::public_transfer(shui, account);
    }

    public entry fun burn<T>(treasury: &mut TreasuryCap<SHUI>, coin: Coin<SHUI>) {
        coin::burn(treasury, coin);
    }

    public entry fun bindMeta(meta:&mut MetaIdentify, phone:string::String, ctx: &mut TxContext) {
        // confition: unbinded
        if (option::is_some(&meta.bind)) {
            let bind_read = option::borrow(&meta.bind);
            assert!(bind_read.status == false, ERR_BINDED);
        };
        option::fill(&mut meta.bind, Bind {
            id:object::new(ctx),       
            phone:phone,
            status:true
        });
    }

    public entry fun unbindMeta(meta:&mut MetaIdentify) {
        assert!(option::is_some(&meta.bind), ERR_UNBINDED);
        let bind_read = option::borrow(&meta.bind);
        assert!(bind_read.status == true, ERR_BINDED);
        let bind_read = option::borrow_mut(&mut meta.bind);
        bind_read.status = false;
    }

    public entry fun deleteMeta(meta: MetaIdentify) {
        let MetaIdentify {id, metaId:_, name:_, charactor, bind} = meta;
        object::delete(id);
        let bind = option::destroy_some(bind);
        let cha = option::destroy_some(charactor);
        let Bind { id, status:_, phone:_} = bind;
        object::delete(id);
        let Inscription {name:_, gender:_, avatar:_ ,race:_ ,level:_,gift:_} = cha;
    }

    public entry fun transferMeta(meta: MetaIdentify, receiver:address) {
        unbindMeta(&mut meta);
        transfer::public_transfer(meta, receiver);
    }

    public entry fun set_ido_swap_whitelists(global: &mut Global, whitelist: vector<address>, ctx: &mut TxContext,) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let (i, len) = (0u64, vector::length(&whitelist));
        while (i < len) {
            let account = vector::pop_back(&mut whitelist);
            table::add(&mut global.ido_whitelist, account, 100_000);
            i = i + 1
        };
    }

    public entry fun set_airdrop_swap_whitelists(global: &mut Global, whitelist: vector<address>, ctx: &mut TxContext,) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let (i, len) = (0u64, vector::length(&whitelist));
        while (i < len) {
            let account = vector::pop_back(&mut whitelist);
            table::add(&mut global.airdrop_whitelist, account, 10_000);
            i = i + 1
        };
    }

    public entry fun change_founder(global: &mut Global, founder:address, ctx: &mut TxContext) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        global.founder = founder;
    }

    public entry fun change_co_founder(global: &mut Global, co_founder:address, ctx: &mut TxContext) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        global.co_founder = co_founder;
    }

    public entry fun change_engine_team(global: &mut Global, engine_team:address, ctx: &mut TxContext) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        global.engine_team = engine_team;
    }

    fun transfer_reserve(global: &mut Global, amount:u64, ctx: &mut TxContext) {
        let value = balance::value(&global.balance_SHUI);
        assert!(value > amount, ERR_BALANCE_NOT_ENOUGH);
        let reserve_balance = balance::split(&mut global.balance_SHUI, amount);
        let shui = coin::from_balance(reserve_balance, ctx);
        transfer::public_transfer(shui, tx_context::sender(ctx));
    }

    public entry fun claim_co_founder_reserve(global:&mut Global, ctx:&mut TxContext) {
        assert!(global.co_founder == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(global.co_founder_reserve_left > 0, ERR_BALANCE_NOT_ENOUGH);
        transfer_reserve(global, CO_FOUNDER_PER_RESERVE, ctx);
        global.co_founder_reserve_left = global.co_founder_reserve_left - 1;
    }

    public entry fun claim_founder_reserve(global: &mut Global, ctx:&mut TxContext) {
        assert!(global.founder == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(global.founder_reserve_left > 0, ERR_BALANCE_NOT_ENOUGH);
        transfer_reserve(global, FOUNDER_PER_RESERVE, ctx);
        global.founder_reserve_left = global.founder_reserve_left - 1;
    }

    public entry fun claim_engine_team_reserve(global: &mut Global, ctx:&mut TxContext) {
        assert!(global.engine_team == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(global.engine_team_reserve_left > 0, ERR_BALANCE_NOT_ENOUGH);
        transfer_reserve(global, ENGINE_TEAM_PER_RESERVE, ctx);
        global.engine_team_reserve_left = global.engine_team_reserve_left - 1;
    }

    public entry fun claim_tech_team_reserve(global: &mut Global, ctx:&mut TxContext) {
        assert!(table::contains(&global.tech_whitelist, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
        assert!(global.tech_team_reserve_left > 0, ERR_BALANCE_NOT_ENOUGH);
        transfer_reserve(global, TECH_TEAM_PER_RESERVE, ctx);
        global.tech_team_reserve_left = global.tech_team_reserve_left - 1;
    }

    public entry fun claim_promote_team_reserve(global: &mut Global, ctx:&mut TxContext) {
        assert!(table::contains(&global.tech_whitelist, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
        assert!(global.promote_team_reserve_left > 0, ERR_BALANCE_NOT_ENOUGH);
        transfer_reserve(global, PROMOTE_TEAM_PER_RESERVE, ctx);
        global.promote_team_reserve_left = global.promote_team_reserve_left - 1;
    }

    public entry fun claim_partner_reserve(global: &mut Global, ctx:&mut TxContext) {
        assert!(table::contains(&global.tech_whitelist, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
        assert!(global.partner_team_reserve_left > 0, ERR_BALANCE_NOT_ENOUGH);
        transfer_reserve(global, PARTNER_PER_RESERVE, ctx);
        global.partner_team_reserve_left = global.partner_team_reserve_left - 1;
    }

    public fun record_swaped_amount(table: &mut Table<address, u64>, amount_culmulate:u64, recepient: address) {
        let value = table::remove(table, recepient);
        table::add(table, recepient, value - amount_culmulate);
    }

    public fun has_swap_amount(table: &mut Table<address, u64>, amount_to_swap:u64, recepient: address): bool {
       let left_amount = *table::borrow(table, recepient);
       left_amount >= amount_to_swap
    }
}