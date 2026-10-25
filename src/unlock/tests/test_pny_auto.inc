/* Native host only: exercise the automatic variant with fake EFI services. */
static int TestAutomaticBoot(void) {
  CHECK(GuPortAutomaticBoot() && GuPortHardwareEnabled());
  for(unsigned c=0;c<23;c++) {
    extra_case=0;app_setup(APP_HANDOFF);
    switch(c) {
      case 1:AutoKeyCase=3;break; /* U must not shorten the countdown. */
      case 2:AutoKeyCase=1;break;
      case 3:AutoKeyCase=8;break; /* Esc at 4.9 seconds. */
      case 4:AutoKeyCase=2;break;
      case 5:st.ConIn=NULL;break;
      case 6:conin.Reset=NULL;break;
      case 7:conin.ReadKeyStroke=NULL;break;
      case 8:AutoKeyCase=6;break;
      case 9:AutoKeyCase=9;break;
      case 10:AutoKeyCase=4;break; /* Cold selectors drift during countdown. */
      case 11:config[0x2c]^=1;break;
      case 12:registers[0x300000/4]^=1;break;
      case 13:app_mode=APP_BAD_HASH;break;
      case 14:PnyFsCase=2;break;
      case 15:registers[SS1/4]=8;break; /* Already unlocked is not retried. */
      case 16:fake.mode=SEC2_RUN_TIMEOUT;break;
      case 17:RecoveryCase=REC_SET_ERROR;break;
      case 18:RecoveryCase=REC_SET_SELECTOR;break;
      case 19:RecoveryCase=REC_ZERO_FB;break;
      case 20:RecoveryCase=REC_CHILD_ROUTE;break;
      case 21:app_mode=APP_SECUREBOOT;break;
      case 22:app_mode=APP_HANDOFF_CHANGED;break;
    }
    volatile EFI_STATUS status=EFI_ABORTED;
    int jumped=setjmp(escape_halt);if(!jumped)status=EfiMain(H(1),&st);
    BOOLEAN success=c==0 || c==1 || c==19 || c==20;
    if(success) {
      CHECK(jumped==2 && windows_started && !halted && AutoWaitUs==5000000);
      CHECK(disconnect_calls==1 && connect_calls==1 && fake.sec2_starts==1 && fake.flrs==1);
      CHECK(!fake.live_maps && !fake.live_buffers && !Gu.allocations);
      if(c==0)CHECK(!key_sent);
      if(c==1)CHECK(key_sent);
    } else {
      CHECK(!windows_started && jumped!=2);
      if(c>=16 && c<=18)CHECK(jumped==1 && halted && Gu.retained);
      else {
        CHECK(!jumped && EFI_ERROR(status) && !disconnect_calls);
        CHECK(!fake.mmio_writes && !fake.maps && !fake.gsp_starts && !fake.sec2_starts && !fake.flrs);
        CHECK(!Gu.allocations && !fake.pool_live);
      }
    }
    CHECK(disconnect_calls<=1 && fake.sec2_starts<=1 && fake.flrs<=1 && !(config[4]&4));
    printf("Automatic USB case %u: Windows=%d release=%llu PASS\n",c,windows_started,(unsigned long long)disconnect_calls);
    dispose_host_fixture();
  }
  for(int i=0;i<5;i++)free((VOID*)originals[i].firmware.data);
  puts("23 automatic USB scenarios passed; EFI, firmware, PCI, DMA and Windows simulated.");
  return 0;
}
