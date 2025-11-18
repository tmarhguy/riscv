
// Debug print
always_ff @(posedge clk_i) begin
     if (id_ex_reg.valid && id_ex_reg.is_branch) begin
         $display("BRANCH EX: PC=%h rs1_addr=%d rs2_addr=%d fwd_a=%d fwd_b=%d rs1_val=%h rs2_val=%h target=%h taken=%d", 
                  id_ex_reg.pc, id_ex_reg.rs1_addr, id_ex_reg.rs2_addr, fwd_a_sel, fwd_b_sel, 
                  ((fwd_a_sel==FWD_EX_MEM) ? ex_mem_reg.alu_result : (fwd_a_sel==FWD_MEM_WB) ? mem_wb_reg.result : id_ex_reg.rs1_data),
                  ((fwd_b_sel==FWD_EX_MEM) ? ex_mem_reg.alu_result : (fwd_b_sel==FWD_MEM_WB) ? mem_wb_reg.result : id_ex_reg.rs2_data),
                  branch_target_ex, branch_taken_ex);
         
         // Forwarding debug
         $display("FWD DEBUG: mw_valid=%d mw_rw=%d mw_rd=%d id_rs1=%d match=%d", 
                  mem_wb_reg.valid, mem_wb_reg.reg_write, mem_wb_reg.rd_addr, id_ex_reg.rs1_addr, 
                  (mem_wb_reg.rd_addr == id_ex_reg.rs1_addr));
     end
     if (mem_wb_reg.valid && mem_wb_reg.reg_write) begin
         $display("WB: PC=%h rd=%d val=%h", mem_wb_reg.pc, mem_wb_reg.rd_addr, mem_wb_reg.result);
     end
end
