module shui_module::metaIdentity {
    use std::string;
    use sui::object::{Self, UID};

    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self};
    use sui::table::{Self};
    use std::vector::{Self};

    friend shui_module::airdrop;

    const ERR_NO_PERMISSION:u64 = 0x004;
    const ERR_UNBINDED:u64 = 0x003;
    const ERR_ALREADY_BIND:u64 = 0x008;
    const ERR_ALPHA_QUOTA_EXHAUSTED:u64 = 0x009;
    const ERR_BETA_QUOTA_EXHAUSTED:u64 = 0x010;
    const ERR_INVALID_TYPE:u64 = 0x011;

    const TYPE_ALPHA:u64 = 0;
    const TYPE_BETA:u64 = 1;

    struct MetaIdentity has key {
        // preserve 0-20000 for airdrop
        id:UID,
        metaId:u64,
        name:string::String,
        phone:string::String,
        email:string::String,
        bind_status: bool,
    }

    struct MetaInfoGlobal has key{
        id:UID,
        creator: address,

        // 0-9999
        meta_alpha_count:u64,

        // 10000-20000
        meta_beta_count:u64,

        // 20001+
        meta_common_user_count:u64,

        // for alpha activity participators
        alpha_whitelist:table::Table<address, u64>,

        // for shui token owners
        beta_whitelist:table::Table<address,u64>,

        // wallet_addr -> meta_addr
        meta_addr_map:table::Table<address, address>,

        register_owner:address
    }

    fun init(ctx: &mut TxContext) {
        let global = MetaInfoGlobal {
            id: object::new(ctx),
            creator:@account,
            meta_alpha_count: 0,
            meta_beta_count:0,
            meta_common_user_count:0,
            alpha_whitelist:table::new<address, u64>(ctx),
            beta_whitelist:table::new<address,u64>(ctx),
            meta_addr_map:table::new<address, address>(ctx),
            register_owner:@register_owner
        };
        transfer::share_object(global);
    }

    public entry fun mintMeta(global: &mut MetaInfoGlobal, name:string::String, phone:string::String, email:string::String, user_addr:address, ctx:&mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(global.register_owner == sender, ERR_NO_PERMISSION);
        assert!(!table::contains(&global.meta_addr_map, user_addr), ERR_ALREADY_BIND);
        let uid = object::new(ctx);
        let meta_addr = object::uid_to_address(&uid);
        let meta = MetaIdentity {
            id: uid,
            metaId: generateUid(global, user_addr),
            name:name,
            phone:phone,
            email: email,
            bind_status: true
        };
        table::add(&mut global.meta_addr_map, user_addr, meta_addr);
        transfer::transfer(meta, user_addr);
    }

    fun generateUid(global: &mut MetaInfoGlobal, addr:address):u64 {
        let metaId;
        if (table::contains(&global.alpha_whitelist, addr)) {
            metaId = global.meta_alpha_count;
            if (metaId >= 10000) {
                metaId = get_common_metaid(global);
            } else {
                global.meta_alpha_count = global.meta_alpha_count + 1;
            }
        } else if (table::contains(&global.beta_whitelist, addr)) {
            metaId = 10000 + global.meta_beta_count;
            if (metaId > 20000) {
                metaId = get_common_metaid(global);
            } else {
                global.meta_beta_count = global.meta_beta_count + 1;
            }
        } else {
            metaId = get_common_metaid(global);
        };
        metaId
    }

    fun get_common_metaid(global: &mut MetaInfoGlobal):u64 {
        let metaId = 20000 + global.meta_common_user_count;
        global.meta_common_user_count = global.meta_common_user_count + 1;
        metaId
    }

    public entry fun bindMeta(meta:&mut MetaIdentity, phone:string::String, email:string::String) {
        assert!(meta.bind_status == false, ERR_ALREADY_BIND);
        meta.phone = phone;
        meta.email = email;
        meta.bind_status = true;
    }

    public entry fun unbindMeta(meta:&mut MetaIdentity) {
        assert!(meta.bind_status == true, ERR_UNBINDED);
        meta.phone = string::utf8(b"");
        meta.email = string::utf8(b"");
        meta.bind_status = false;
    }

    public fun transferMeta(global: &mut MetaInfoGlobal, meta: MetaIdentity, receiver:address, ctx:&mut TxContext) {
        // todo: convert to kiosk architecture
        _ = table::remove(&mut global.meta_addr_map, tx_context::sender(ctx));
        unbindMeta(&mut meta);
        transfer::transfer(meta, receiver);
    }

    public entry fun deleteMeta(meta: MetaIdentity) {
        let MetaIdentity {id, metaId:_, name:_, phone:_, email:_, bind_status:_} = meta;
        object::delete(id);
    }

    public fun getMetaId(meta: &MetaIdentity):u64 {
        meta.metaId
    }

    public fun is_active(meta: &MetaIdentity):bool {
        meta.bind_status
    }

    public fun add_whitelists_by_type(global: &mut MetaInfoGlobal, whitelist: vector<address>, type:u64, ctx: &mut TxContext) {
        assert!(@meta_manager == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(type >= TYPE_ALPHA && type <= TYPE_BETA, ERR_INVALID_TYPE);
        let whitelist_table;
        if (type == TYPE_ALPHA) {
            whitelist_table = &mut global.alpha_whitelist;
        } else {
            whitelist_table = &mut global.beta_whitelist;
        };
        let (i, len) = (0u64, vector::length(&whitelist));
        while (i < len) {
            let account = vector::pop_back(&mut whitelist);
            table::add(whitelist_table, account, 0);
            i = i + 1
        };
    }

    public fun add_whitelist_by_type(global: &mut MetaInfoGlobal, account: address, type:u64, ctx: &mut TxContext) {
        assert!(@meta_manager == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(type >= TYPE_ALPHA && type <= TYPE_BETA, ERR_INVALID_TYPE);
        let whitelist_table;
        if (type == TYPE_ALPHA) {
            whitelist_table = &mut global.alpha_whitelist;
        } else {
            whitelist_table = &mut global.beta_whitelist;
        };
        assert!(table::length(whitelist_table) == 0, 1);
        table::add(whitelist_table, account, 0);
    }

    public fun query_meta_addr(global: &MetaInfoGlobal, user_addr:address): &address {
        table::borrow(&global.meta_addr_map, user_addr)
    }

    public fun query_test_res():u64 { // for test
        1233
    }

    public fun change_register_owner(global: &mut MetaInfoGlobal, new_owner:address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == global.creator, ERR_NO_PERMISSION);
        global.register_owner = new_owner;
    }
}