module shui_module::shui {
    use std::option::{Self};
    use sui::coin::{Self, Coin, TreasuryCap, destroy_zero};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use std::vector::{Self};
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::pay;
    use shui_module::race::{Self};
    use shui_module::level::{Self};
    use shui_module::gift::{Self};
    use shui_module::avatar::{Self};
    use sui::table::{Self, Table};
    use shui_module::roles::{Self, RuleInfo};

    const TYPE_FOUNDER:u64 = 0;
    const TYPE_CO_FOUNDER:u64 = 1;
    const TYPE_ENGINE_TEAM:u64 = 2;
    const TYPE_TECH_TEAM:u64 = 3;
    const TYPE_PROMOTE_TEAM:u64 = 4;
    const TYPE_PARTNER:u64 = 5;
    const TYPE_ANGLE_INVEST:u64 = 6;
    const TYPE_PUBLIC:u64 = 7;

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

    const TOTAL_SUPPLY: u64 = 2_100_000_000;
    const FOUNDATION_SUPPLY:u64 = 50_000_000;
    const DAO_SUPPLY:u64 = 50_000_000;

    struct SHUI has drop {}
    struct Global has key {
        id: UID,
        supply: u64,
        balance_SUI: Balance<SUI>,
        balance_SHUI: Balance<SHUI>,
        creator: address,

        founder_whitelist: Table<address, u64>,
        co_founder_whitelist: Table<address, u64>,
        game_engine_team_whitelist: Table<address, u64>,
        tech_whitelist: Table<address, u64>,
        promote_whitelist: Table<address, u64>,
        partner_whitelist: Table<address, u64>,
        angle_invest_whitelist: Table<address, u64>,
        players_count:u64,
    }

    struct MetaIdentify has key {
        // preserve 0-20000 for airdrop
        id:UID,
        metaId:u64,
        name:string::String,
        phone:string::String,
        bind_status: bool,
        bind_charactor: address,
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
            supply: TOTAL_SUPPLY,
            balance_SUI: balance::zero(),
            balance_SHUI: balance::zero(),

            founder_whitelist: table::new<address, u64>(ctx),
            co_founder_whitelist: table::new<address, u64>(ctx),
            game_engine_team_whitelist: table::new<address, u64>(ctx),
            tech_whitelist: table::new<address, u64>(ctx),
            promote_whitelist:  table::new<address, u64>(ctx),
            partner_whitelist: table::new<address, u64>(ctx),
            angle_invest_whitelist: table::new<address, u64>(ctx),

            players_count:0,
        };
        let total_shui = mint(&mut adminCap, TOTAL_SUPPLY, ctx);
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
        let balance = coin::into_balance<SHUI>(
            total_shui
        );
        balance::join(&mut global.balance_SHUI, balance);
        transfer::share_object(global);
    }

    public entry fun createMetaIdentify(global: &mut Global, name:string::String, ctx: &mut TxContext) {
        // todo: exist judgement
        global.players_count = global.players_count + 1;
        let metaId = global.players_count;

        // start from 20000 if not internal
        if (global.creator != tx_context::sender(ctx)) {
            metaId = metaId + 20_000;
        };

        let charactor = new_empty_charactor(ctx);
        let meta = MetaIdentify {
            id:object::new(ctx),
            metaId:metaId,
            name:name,
            bind_charactor: object::uid_to_address(&charactor.id),
            bind_status: false,
            phone:string::utf8(b""),
        };
        transfer::transfer(charactor, tx_context::sender(ctx));
        transfer::transfer(meta, tx_context::sender(ctx));
    }

    fun new_empty_charactor(ctx: &mut TxContext):Inscription {
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

    public fun mint(treasuryCap:&mut TreasuryCap<SHUI>, amount:u64, ctx:&mut TxContext) : Coin<SHUI>{
        coin::mint(treasuryCap, amount, ctx)
    }

    public entry fun transfer_dao_reserve(global: &mut Global, type:u64, ctx:&mut TxContext) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let account = @dao_reserve_wallet;
        let airdrop_balance = balance::split(&mut global.balance_SHUI, DAO_SUPPLY);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, account);
    }

    public entry fun transfer_foundation_reserve(global: &mut Global, ctx:&mut TxContext) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let account = @foundation_reserve_wallet;
        let airdrop_balance = balance::split(&mut global.balance_SHUI, FOUNDATION_SUPPLY);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, account);
    }

    fun get_table_by_type(global: &mut Global, type:u64) : &mut Table<address, u64> {
        &mut global.founder_whitelist
    }

    public entry fun swap<T> (global: &mut Global, rule_info: &RuleInfo, sui_pay_amount:u64, coins:vector<Coin<SUI>>, type:u64, ctx:&mut TxContext) {
        assert!(type >= TYPE_FOUNDER && type <= TYPE_PUBLIC, ERR_INVALID_TYPE);
        let ratio = roles::get_ratio_by_type(rule_info, type);
        let limit = roles::get_swap_num_limit_by_type(rule_info, type);
        let recepient = tx_context::sender(ctx);
        let whitelist_table;
        if (type == TYPE_FOUNDER) {
            whitelist_table = &mut global.founder_whitelist;
        } else if (type == TYPE_CO_FOUNDER) {
            whitelist_table = &mut global.co_founder_whitelist;
        } else if (type == TYPE_ENGINE_TEAM) {
            whitelist_table = &mut global.game_engine_team_whitelist;
        } else if (type == TYPE_TECH_TEAM) {
            whitelist_table = &mut global.tech_whitelist;
        } else if (type == TYPE_PROMOTE_TEAM) {
            whitelist_table = &mut global.promote_whitelist;
        } else if (type == TYPE_PARTNER) {
            whitelist_table = &mut global.partner_whitelist;
        } else if (type == TYPE_ANGLE_INVEST) {
            whitelist_table = &mut global.angle_invest_whitelist;
        } else {
            whitelist_table = &mut global.angle_invest_whitelist;
        };
        if (type != TYPE_PUBLIC) {
            assert!(table::contains(whitelist_table, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
            assert!(has_swap_amount(whitelist_table, sui_pay_amount * ratio, recepient), EXCEED_SWAP_LIMIT);
        };
        let account = tx_context::sender(ctx);
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);
        assert!(coin::value(&merged_coin) >= 1, ERR_SWAP_MIN_ONE_SUI);
        assert!(sui_pay_amount <= limit, ERR_SWAP_MIN_ONE_SUI);
        let balance = coin::into_balance<SUI>(
            coin::split<SUI>(&mut merged_coin, sui_pay_amount * 1_000_000_000, ctx)
        );
        balance::join(&mut global.balance_SUI, balance);
        if (coin::value(&merged_coin) > 0) {
            transfer::public_transfer(merged_coin, account)
        } else {
            destroy_zero(merged_coin)
        };
        let shui_amount:u64 = sui_pay_amount * ratio;
        let airdrop_balance = balance::split(&mut global.balance_SHUI, shui_amount * 1_000_000);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, account);
        if (type != TYPE_PUBLIC) {
            record_swaped_amount(whitelist_table, sui_pay_amount * ratio, recepient);
        };
    }

    public entry fun burn<T>(treasury: &mut TreasuryCap<SHUI>, coin: Coin<SHUI>) {
        coin::burn(treasury, coin);
    }

    public entry fun bindMeta(meta:&mut MetaIdentify, phone:string::String) {
        assert!(meta.bind_status == false, ERR_ALREADY_BIND);
        meta.phone = phone;
        meta.bind_status = true;
    }

    public entry fun unbindMeta(meta:&mut MetaIdentify) {
        assert!(meta.bind_status == true, ERR_UNBINDED);
        meta.phone = string::utf8(b"");
        meta.bind_status = false;
    }

    public entry fun deleteMeta(meta: MetaIdentify) {
        let MetaIdentify {id, metaId:_, name:_, phone:_, bind_status:_, bind_charactor:_} = meta;
        object::delete(id);
    }

    fun destroy_charactor(charactor: Inscription) {
        let Inscription {id, name:_, gender:_, avatar:_ ,race:_ ,level:_,gift:_} = charactor;
        object::delete(id);
    }

    public fun transferMeta(meta: MetaIdentify, receiver:address) {
        unbindMeta(&mut meta);
        transfer::transfer(meta, receiver);
    }

    public fun add_whitelist_by_type(global: &mut Global, ruleInfo:&RuleInfo, account: address, type:u64, ctx: &mut TxContext) {
        assert!(type >= TYPE_FOUNDER && type <= TYPE_ANGLE_INVEST, ERR_INVALID_TYPE);
        let reserve = roles::get_per_reserve_by_type(ruleInfo, type);
        let whitelist_table;
         if (type == TYPE_FOUNDER) {
            whitelist_table = &mut global.founder_whitelist;
        } else if (type == TYPE_CO_FOUNDER) {
            whitelist_table = &mut global.co_founder_whitelist;
        } else if (type == TYPE_ENGINE_TEAM) {
            whitelist_table = &mut global.game_engine_team_whitelist;
        } else if (type == TYPE_TECH_TEAM) {
            whitelist_table = &mut global.tech_whitelist;
        } else if (type == TYPE_PROMOTE_TEAM) {
            whitelist_table = &mut global.promote_whitelist;
        } else if (type == TYPE_PARTNER) {
            whitelist_table = &mut global.partner_whitelist;
        } else {
            whitelist_table = &mut global.angle_invest_whitelist;
        };
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(table::length(whitelist_table) == 0, 1);
        table::add(whitelist_table, account, reserve);
    }

    public fun add_whitelists_by_type(global: &mut Global, ruleInfo:&RuleInfo, whitelist: vector<address>, type:u64, ctx: &mut TxContext) {
        assert!(type >= TYPE_FOUNDER && type <= TYPE_ANGLE_INVEST, ERR_INVALID_TYPE);
        let reserve = roles::get_per_reserve_by_type(ruleInfo, type);
        let whitelist_table;
         if (type == TYPE_FOUNDER) {
            whitelist_table = &mut global.founder_whitelist;
        } else if (type == TYPE_CO_FOUNDER) {
            whitelist_table = &mut global.co_founder_whitelist;
        } else if (type == TYPE_ENGINE_TEAM) {
            whitelist_table = &mut global.game_engine_team_whitelist;
        } else if (type == TYPE_TECH_TEAM) {
            whitelist_table = &mut global.tech_whitelist;
        } else if (type == TYPE_PROMOTE_TEAM) {
            whitelist_table = &mut global.promote_whitelist;
        } else if (type == TYPE_PARTNER) {
            whitelist_table = &mut global.partner_whitelist;
        } else {
            whitelist_table = &mut global.angle_invest_whitelist;
        };
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let (i, len) = (0u64, vector::length(&whitelist));
        while (i < len) {
            let account = vector::pop_back(&mut whitelist);
            table::add(whitelist_table, account, reserve);
            i = i + 1
        };
    }

    fun record_swaped_amount(table: &mut Table<address, u64>, amount_culmulate:u64, recepient: address) {
        let value = table::remove(table, recepient);
        table::add(table, recepient, value - amount_culmulate);
    }

    fun has_swap_amount(table: &Table<address, u64>, amount_to_swap:u64, recepient: address): bool {
       let left_amount = *table::borrow(table, recepient);
       left_amount >= amount_to_swap
    }
}