library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pRSP is

   type tDMEMarray is array(0 to 15) of std_logic_vector(7 downto 0);

   type VECTOR_CALCTYPE is
   (
      VCALC_VMULF,
      VCALC_VMULU,
      VCALC_VRNDP,
      VCALC_VMULQ,
      VCALC_VMUDL,
      VCALC_VMUDM,
      VCALC_VMUDN,
      VCALC_VMUDH,
      VCALC_VMACF,
      VCALC_VMACU,
      VCALC_VRNDN,
      VCALC_VMACQ,
      VCALC_VMADL,
      VCALC_VMADM,
      VCALC_VMADN,
      VCALC_VMADH,
      VCALC_VADD,
      VCALC_VSUB,
      VCALC_VADDC,
      VCALC_VSUBC,
      VCALC_VABS,
      VCALC_VSAR,
      VCALC_VLT,
      VCALC_VEQ,
      VCALC_VNE,
      VCALC_VGE,
      VCALC_VCL,
      VCALC_VCH,
      VCALC_VCR,
      VCALC_VMRG,
      VCALC_VAND,
      VCALC_VNAND,
      VCALC_VOR,
      VCALC_VNOR,
      VCALC_VXOR,
      VCALC_VNXOR,
      VCALC_VRCP,
      VCALC_VRCPL,
      VCALC_VRCPH,
      VCALC_VMOV,
      VCALC_VSRQ,
      VCALC_VSRQL,
      VCALC_VRSQH,
      VCALC_VZERO,
      VCALC_VNOP
   );
   
   type toutputSelect is
   (
      OUTPUT_ZERO,
      OUTPUT_ACCL,
      OUTPUT_ACCM,
      OUTPUT_ACCH,
      CLAMP_SIGNED,
      CLAMP_UNSIGNED,
      CLAMP_VMACU,
      CLAMP_MPEG,
      CLAMP_RND,
      CLAMP_ADDSUB
   );

end package;