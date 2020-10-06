/*
 * Copyright 2020 PSNC
 *
 * Author: Damian Parniewicz
 *
 * Created in the GN4-3 project.
 *
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifdef BMV2

control Int_source(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

#elif TOFINO

control Int_source(inout headers hdr, inout metadata meta, in ingress_intrinsic_metadata_t standard_metadata) {

#endif

    action configure_source(bit<8> max_hop, bit<5> ins_cnt, bit<16> ins_mask) {
        hdr.int_shim.setValid();
        hdr.int_shim.int_type = 1;
        hdr.int_shim.len = (bit<8>)INT_SHIM_HEADER_LEN_BYTES;
        
        hdr.int_header.setValid();
        hdr.int_header.ver = 1;
        hdr.int_header.rep = 0;
        hdr.int_header.c = 0;
        hdr.int_header.e = 0;
        hdr.int_header.rsvd1 = 0;
        hdr.int_header.rsvd2 = 0;
        hdr.int_header.ins_cnt = ins_cnt;
        hdr.int_header.max_hops = max_hop;
        hdr.int_header.total_hops = 0;  //will be increased immediately by 1 within transit process
        hdr.int_header.instruction_mask = ins_mask;
        
        hdr.int_tail.setValid();
        hdr.int_tail.next_proto = hdr.ipv4.protocol;
        hdr.int_tail.dscp = hdr.ipv4.dscp;
        
        hdr.ipv4.dscp = IPv4_DSCP_INT;   // indicates that INT header in the packet
        hdr.ipv4.totalLen = hdr.ipv4.totalLen + INT_ALL_HEADER_LEN_BYTES;  // adding size of INT headers
        
        //if (hdr.udp.isValid()){
        hdr.udp.len = hdr.udp.len + INT_ALL_HEADER_LEN_BYTES;
        hdr.int_tail.dest_port = hdr.udp.dstPort;
        //}
    }
    
    table tb_int_source {
        actions = {
            configure_source;
        }
        #ifdef BMV2
        key = {
            hdr.ipv4.srcAddr     : ternary;
            hdr.ipv4.dstAddr     : ternary;
            meta.layer34_metadata.l4_src: ternary;
            meta.layer34_metadata.l4_dst: ternary;
        }
        #endif
        size = 127;
        default_action =
            configure_source(4,4, 0x00cc);
    }

    action activate_source() {
        meta.int_metadata.source = 1w1;
    }
    table tb_activate_source {
        actions = {
            activate_source;
        }
        #ifdef BMV2
        key = {
            standard_metadata.ingress_port: exact;
        }
        #endif
        size = 255;
    }


    apply {
        #ifdef BMV2
        tb_activate_source.apply();
        if (meta.int_metadata.source == 1w1)
        #endif
        //TODO: find TOFINO equivalent
            tb_int_source.apply();
    }
}