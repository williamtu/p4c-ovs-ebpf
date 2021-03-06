/* OVS P4 header file 
 * - Copy header from include/headers.p4, parser.p4 at github.com/p4lang/switch.git
 * - Copy struct definition from OVS
 */

#define ETH_P_8021Q     0x8100 /* 802.1Q VLAN Extended Header  */
#define ETH_P_8021AD    0x88A8 /* 802.1ad Service VLAN     */
#define ETH_P_ARP	0x0806 
#define ETH_P_IPV4	0x0800
#define ETH_P_IPV6	0x86DD

#define IPPROTO_ICMP    1
#define IPPROTO_IGMP    2
#define IPPROTO_TCP     6
#define IPPROTO_UDP     17
#define IPPROTO_GRE     47
#define IPPROTO_SCTP    132

header_type ethernet_t {
    fields {
        dstAddr : 48;
        srcAddr : 48;
        etherType : 16;
    }
}

header_type vlan_tag_t {
    fields {
        pcp : 3;
        cfi : 1;
        vid : 12;
        etherType : 16;
    }
}

header_type mpls_t {
    fields {
        label : 20;
        exp : 3;
        bos : 1;
        ttl : 8;
    }
}

header_type arp_rarp_t {
    fields {
        hwType : 16;
        protoType : 16;
        hwAddrLen : 8;
        protoAddrLen : 8;
        opcode : 16;
    }
}

header_type arp_rarp_ipv4_t {
    fields {
        srcHwAddr : 48;
        srcProtoAddr : 32;
        dstHwAddr : 48;
        dstProtoAddr : 32;
    }
}

header_type ipv4_t {
    fields {
        version : 4;
        ihl : 4;
        diffserv : 8;
        totalLen : 16;
        identification : 16;
        flags : 3;
        fragOffset : 13;
        ttl : 8;
        protocol : 8;
        hdrChecksum : 16;
        srcAddr : 32;
        dstAddr: 32;
    }
}

header_type ipv6_t {
    fields {
        version : 4;
        trafficClass : 8;
        flowLabel : 20;
        payloadLen : 16;
        nextHdr : 8;
        hopLimit : 8;
        srcAddr : 128;
        dstAddr : 128;
    }
}

header_type icmp_t {
    fields {
        typeCode : 16;
        hdrChecksum : 16;
    }
}

header_type tcp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        seqNo : 32;
        ackNo : 32;
        dataOffset : 4;
        res : 4;
        flags : 8;
        window : 16;
        checksum : 16;
        urgentPtr : 16;
    }
}

header_type udp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        length_ : 16;
        checksum : 16;
    }
}

header_type sctp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        verifTag : 32;
        checksum : 32;
    }
}

header_type gre_t {
    fields {
        C : 1;
        R : 1;
        K : 1;
        S : 1;
        s : 1;
        recurse : 3;
        flags : 5;
        ver : 3;
        proto : 16;
    }
}
/* ----------------- metadata ---------------- */
header_type pkt_metadata_t {
	fields {
		recirc_id : 32; /* Recirculation id carried with the
                                   recirculating packets. 0 for packets
                                   received from the wire. */
		dp_hash : 32;           /* hash value computed by the recirculation
                                   	   action. */
		skb_priority : 32;      /* Packet priority for QoS. */
		pkt_mark : 32;          /* Packet mark. */
		ct_state : 16;          /* Connection state. */
		ct_zone : 16;           /* Connection zone. */
		ct_mark : 32;           /* Connection mark. */
		ct_label : 128;         /* Connection label. */
		in_port : 32; 		/* Input port. */
	}
}

header_type flow_tnl_t {
	fields {
		/* struct flow_tnl: 
                 * Tunnel information used in flow key and metadata.
                 */
		ip_dst : 32;
		ipv6_dst : 64;
		ip_src: 32;
		ipv6_src : 64;
		tun_id : 64;
		flags : 16;
		ip_tos : 8;
		ip_ttl : 8;
		tp_src : 16;
		tp_dst : 16;
		gbp_id : 16;
		gbp_flags : 8;
		pad1: 40;        /* Pad to 64 bits. */
		/* struct tun_metadata metadata; */
	}
}

header ethernet_t ethernet;
header ipv4_t ipv4;
header ipv6_t ipv6;
header arp_rarp_t arp;
header tcp_t tcp;
header udp_t udp;
header icmp_t icmp;
header vlan_tag_t vlan;
metadata pkt_metadata_t md;
metadata flow_tnl_t tnl_md;

/* ------------------ A tree, no loop is allowed -------------------------------- */

parser start {
	return parse_ethernet;
}

parser parse_ethernet{
	extract(ethernet);
	return select(latest.etherType) {
        ETH_P_8021Q: parse_vlan;
        ETH_P_8021AD: parse_vlan;
		ETH_P_ARP: parse_arp;
		ETH_P_IPV4: parse_ipv4;
		ETH_P_IPV6: parse_ipv6;
		default: ingress;
	}
}

parser parse_vlan {
    extract(vlan);
    return select(latest.etherType) {
		ETH_P_ARP: parse_arp;
		ETH_P_IPV4: parse_ipv4;
		ETH_P_IPV6: parse_ipv6;
		default: ingress;
    }
}

parser parse_arp {
	extract(arp);
	return ingress;
}

parser parse_ipv4 {
	extract(ipv4);
	return select(latest.protocol) {
		IPPROTO_TCP: parse_tcp;
		IPPROTO_UDP: parse_udp;
		IPPROTO_ICMP: parse_icmp;
		default: ingress;
	}
}

parser parse_ipv6 {
	extract(ipv6);
	return select(latest.nextHdr) {
		IPPROTO_TCP: parse_tcp;
		IPPROTO_UDP: parse_udp;
		IPPROTO_ICMP: parse_icmp;
		default: ingress;
	}
}

parser parse_tcp {
	extract(tcp);
	return ingress;
}

parser parse_udp {
	extract(udp);
	return ingress;
}

parser parse_icmp {
	extract(icmp);
	return ingress;
}

/* ------------------------------------------------------------------------- */

action nop() {}

table ovs_tbl {
	reads {
		/* we are not using it. */
		ipv4.dstAddr: exact;
		md.in_port: exact;
		tnl_md.tun_id: exact;
	}
	actions {
		nop;
	}
}

control ingress
{
	apply(ovs_tbl);
}

