module shui_module::metaIdentity {
    use std::string;
    use sui::object::{Self, UID};

    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self};

    friend shui_module::airdrop;

    const ERR_NO_PERMISSION:u64 = 0x004;
    const ERR_UNBINDED:u64 = 0x003;
    const ERR_ALREADY_BIND:u64 = 0x008;

    struct MetaIdentity has key {
        // preserve 0-20000 for airdrop
        id:UID,
        metaId:u64,
        name:string::String,
        phone:string::String,
        email:string::String,
        bind_status: bool
    }

    public entry fun mintMeta(name:string::String, phone:string::String, email:string::String, ctx:&mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(@meta_manager == sender, ERR_NO_PERMISSION);
        let meta = MetaIdentity {
            id: object::new(ctx),
            metaId: generateUid(sender),
            name:name,
            phone:phone,
            email: email,
            bind_status: true
        };
        transfer::transfer(meta, sender);
    }

    fun generateUid(addr:address):u64 {
        // differ into 3 levels
        00001
    }

    public entry fun bindMeta(meta:&mut MetaIdentity, phone:string::String, email:string::String) {
        assert!(meta.bind_status == false, ERR_ALREADY_BIND);
        meta.phone = phone;
        meta.email = email;
        meta.bind_status = true;
    }

    public entry fun unbindMeta(meta:&mut MetaIdentity) {
        // todo:think about the airdrop bind time bug when unbind....
        assert!(meta.bind_status == true, ERR_UNBINDED);
        meta.phone = string::utf8(b"");
        meta.email = string::utf8(b"");
        meta.bind_status = false;
    }

    public fun transferMeta(meta: MetaIdentity, receiver:address) {
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

    public fun is_active(meta: &MetaIdentity): bool {
        meta.bind_status
    }
}