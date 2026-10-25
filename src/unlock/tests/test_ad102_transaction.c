/* SPDX-License-Identifier: GPL-2.0-only */
#define main old_fixture_main
#include "test_efi_transaction.c"
#undef main
#include "ad102_cases.h"
int main(int argc,char **argv) {
 setvbuf(stdout,NULL,_IONBF,0);CHECK(argc==3);load_fixture_assets(argv[1],argv[2]);
 for(UINTN c=0;c<sizeof(ad_cases)/sizeof(*ad_cases);c++) {
  int mode=ad_cases[c];setup((enum scenario)mode);
  UINT64 mask=0xffffffffffffULL;
  struct pci_dev device={.dev={.dma_mask=&mask,.coherent_dma_mask=0xfffffffffULL},.pm_cap=0x60,.refs=1};
  struct gpu_unlock_610_shared shared={0};
  int result=gpu_unlock_610_load_shared(&device,&shared);CHECK(!result);
  result=gpu_unlock_610_unlock(&device,&shared);gpu_unlock_610_release_shared(&shared);
  BOOLEAN safe=GuSafeToReturn();
  if(ad_success(mode)) {
   CHECK(!result && safe && Gu.quiesced && !Gu.retained && !Gu.fault);
   CHECK(fake.gsp_starts==1 && fake.sec2_starts==expected_sec2_starts(mode) && fake.flrs==1);
   CHECK(registers[SS0/4]==(mode==AD_SS0_REJECT?0x31322012:0x88888888));
   CHECK(registers[SS1/4]==((mode==AD_SS1_REJECT || mode==SELECTOR_LOST)?7:8));
   CHECK(strstr(fake.log,"SELECTOR RESULT: SS0") && strstr(fake.log,"SELECTOR RESULT: SS1"));
   CHECK(!fake.live_maps && !fake.live_buffers && !fake.pool_live);
   CHECK(strstr(fake.log,"required_expected=1") && strstr(fake.log,"marker_ok=1"));
  } else {
   CHECK(result || mode==UNMAP_FAIL);
   if(mode==MAP_FAIL || mode==MAP_PARTIAL || mode==BME_READBACK_FAIL) {
    CHECK(safe && !Gu.started && !Gu.retained && !fake.mmio_writes);
    CHECK(!fake.live_maps && !fake.live_buffers && !fake.pool_live);
   } else {
    CHECK(!safe && Gu.retained);
    CHECK(fake.live_maps && !fake.frees);
   }
   if(ad_before_selectors(mode)) {
    CHECK(registers[SS0/4]==0x31322012 && registers[SS1/4]==7 && !fake.flrs);
   }
  }
  if(mode==AD_MARKER_MISSING || mode==AD_MARKER_WRONG || mode==AD_MARKER_NO_OPEN ||
     mode==PLM_SECOND_TARGET_TIMEOUT || mode==AD_THIRD_FAIL || mode==AD_FEAT_FAIL ||
     mode==PLM_WRONG_WPR_CFG_MASK || mode==PLM_PREOPEN_SKIP ||
     mode==RESET_CHANGES_WPR_FIRST || mode==RESET_CHANGES_WPR_LATER ||
     mode==RESET_CORRUPTS_PAYLOAD_FIRST || mode==RESET_CORRUPTS_PAYLOAD_LATER ||
     mode==PRE_RESET_RUNNING)
   CHECK(fake.sec2_starts==expected_sec2_starts(mode));
  if(mode==AD_MARKER_MISSING || mode==AD_MARKER_WRONG)CHECK(strstr(fake.log,"marker_ok=0"));
  if(mode==AD_MARKER_NO_OPEN)CHECK(strstr(fake.log,"all_expected=0 marker=0x67b00001 marker_ok=1"));
  if(mode==PLM_PRIOR_RELOCK)CHECK(fake.sec2_starts==1 && !fake.flrs && registers[SS1/4]==7);
  if(mode==SEC2_RUN_TIMEOUT || mode==PRE_RESET_RUNNING) {
   CHECK(strstr(fake.log,"Stock signature restore deferred"));
   CHECK(fake.meta_dma && le64(dma_pointer(fake.meta_dma,256)+80)==64000);
  }
  CHECK(!EFI_ERROR(GuClearMaster()) && !(config[4]&4));
  CHECK(fake.gsp_starts<=1 && fake.sec2_starts<=1 && fake.flrs<=1);
  CHECK(!fake.pio_reads && !fake.pio_writes && !fake.dmem_reads);
  printf("AD102 core %s: result=%d safe=%u starts=%zu/%zu FLR=%zu PASS\n",case_names[mode],result,safe,fake.gsp_starts,fake.sec2_starts,fake.flrs);
  dispose_host_fixture();
 }
 for(UINTN i=0;i<5;i++)free((VOID *)GuAssets[i].firmware.data);
 printf("%zu AD102 core scenarios passed; PCI/MMIO/DMA/firmware simulated.\n",sizeof(ad_cases)/sizeof(*ad_cases));
 return 0;
}
