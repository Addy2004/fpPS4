unit subr_dynlib;

{$mode ObjFPC}{$H+}
{$CALLING SysV_ABI_CDecl}

interface

uses
 sysutils,
 mqueue,
 elf64,
 kern_thr,
 kern_rtld;

type
 p_rel_data=^t_rel_data;
 t_rel_data=record
  //entry:TAILQ_ENTRY;
  //vm_obj:vm_object_t;
  //refs:Integer;
  //full_size:QWORD;

  symtab_addr:p_elf64_sym;
  symtab_size:QWORD;

  strtab_addr:pchar;
  strtab_size:QWORD;

  pltrela_addr:p_elf64_rela;
  pltrela_size:QWORD;

  rela_addr:p_elf64_rela;
  rela_size:QWORD;

  hash_addr:Pointer;
  hash_size:QWORD;

  dynamic_addr:p_elf64_dyn;
  dynamic_size:QWORD;

  sce_comment_addr:PByte;
  sce_comment_size:QWORD;

  sce_dynlib_addr:Pointer;
  sce_dynlib_size:QWORD;

  execpath:pchar;

  buckets:PQWORD;
  buckets_size:QWORD;

  chains:PQWORD;
  chains_size:QWORD;

  hashsize:DWORD;
  dynsymcount:DWORD;

  original_filename:pchar;

  //void * sce_dynlib_data;
  //void * elf_hdr;
 end;

 p_lib_info=^t_lib_info;
 t_lib_info=record
  entry:TAILQ_ENTRY;

  lib_path   :PAnsiChar;
  lib_dirname:PAnsiChar;

  ref_count:Integer;
  id       :Integer;

  map_base :Pointer;
  map_size :QWORD;
  text_size:QWORD;

  data_addr:Pointer;
  data_size:QWORD;

  relro_addr:Pointer;
  relro_size:QWORD;

  relocbase :Pointer;
  entry_addr:Pointer;

  tls_index:QWORD;

  tls_init_addr:Pointer;
  tls_init_size:QWORD;
  tls_size     :QWORD;
  tls_offset   :QWORD;
  tls_align    :QWORD;

  pltgot:Pointer;

  needed     :TAILQ_HEAD; //Needed_Entry
  lib_table  :TAILQ_HEAD; //Lib_Entry
  //lib_modules:TAILQ_HEAD; //Lib_Entry
  names      :TAILQ_HEAD; //Name_Entry

  init_proc_addr:Pointer;
  fini_proc_addr:Pointer;

  eh_frame_hdr_addr:Pointer;
  eh_frame_hdr_size:QWORD;

  eh_frame_addr:Pointer;
  eh_frame_size:QWORD;

  loaded:Integer;

  //t_rtld_bits rtld_flags;

  tls_done    :Integer;
  init_scanned:Integer;
  init_done   :Integer;
  init_fini   :Integer;
  textrel     :Integer;

  dldags    :TAILQ_HEAD; //Objlist_Entry
  dagmembers:TAILQ_HEAD; //Objlist_Entry

  relo_bits_process:PByte;

  rel_data:p_rel_data;

  fingerprint:array[0..19] of Byte;

  module_param:pSceModuleParam;
 end;

 p_Objlist_Entry=^Objlist_Entry;
 Objlist_Entry=record
  link:TAILQ_ENTRY;
  obj :p_lib_info;
 end;

 p_Needed_Entry=^Needed_Entry;
 Needed_Entry=record
  link :TAILQ_ENTRY;
  obj  :p_lib_info;
  flags:QWORD;
  name :Char;
 end;

 p_Name_Entry=^Name_Entry;
 Name_Entry=record
  link:TAILQ_ENTRY;
  name:Char;
 end;

 p_Lib_Entry=^Lib_Entry;
 Lib_Entry=record
  link  :TAILQ_ENTRY;
  dval  :TLibraryValue;
  attr  :WORD;
  export:WORD;
 end;

 p_dynlibs_info=^t_dynlibs_info;
 t_dynlibs_info=record
  lib_list   :TAILQ_HEAD; //p_lib_info
  libprogram :p_lib_info;
  libkernel  :p_lib_info;
  obj_count  :Integer;
  list_global:TAILQ_HEAD; //p_Objlist_Entry
  needed     :TAILQ_HEAD; //p_Needed_Entry
  init_list  :TAILQ_HEAD; //p_Objlist_Entry
  fini_list  :TAILQ_HEAD; //p_Objlist_Entry

  init_proc_list:TAILQ_HEAD; //p_Objlist_Entry
  fini_proc_list:TAILQ_HEAD; //p_Objlist_Entry

  tls_last_offset:QWORD;
  tls_last_size  :QWORD;
  d_tls_count    :QWORD;

  tls_count   :Integer;
  tls_max     :Integer;

  proc_param_addr:pSceProcParam;
  proc_param_size:QWORD;

  sceKernelReportUnpatchedFunctionCall:Pointer;
  __freeze:Pointer;
  sysc_s00:Pointer;
  sysc_e00:Pointer;

  dyn_non_exist:Integer;

 end;

function  scan_phdr(imgp:p_image_params;phdr:p_elf64_phdr;count:Integer):Integer;
function  trans_prot(flags:Elf64_Word):Byte;

function  obj_new():p_lib_info;
procedure obj_free(lib:p_lib_info);

function  obj_get_str(lib:p_lib_info;offset:Int64):pchar;
procedure object_add_name(obj:p_lib_info;name:pchar);
function  object_match_name(obj:p_lib_info;name:pchar):Boolean;

function  Needed_new(lib:p_lib_info;str:pchar):p_Needed_Entry;
function  Lib_new(d_tag:DWORD;d_val:QWORD):p_Lib_Entry;

function  elf64_get_eh_frame_info(hdr:p_eh_frame_hdr;
                                  hdr_size :QWORD;
                                  hdr_vaddr:QWORD;
                                  data_size:QWORD;
                                  eh_frame_addr:PPointer;
                                  eh_frame_size:PQWORD):Integer;

procedure _set_lib_path(lib:p_lib_info;path:PAnsiChar);

procedure release_per_file_info_obj(lib:p_lib_info);
function  acquire_per_file_info_obj(imgp:p_image_params;new:p_lib_info):Integer;

procedure initlist_add_objects(var fini_proc_list:TAILQ_HEAD;
                               obj :p_lib_info;
                               tail:p_lib_info;
                               var init_proc_list:TAILQ_HEAD);

procedure initlist_add_neededs(var fini_proc_list:TAILQ_HEAD;
                               needed:p_Needed_Entry;
                               var init_proc_list:TAILQ_HEAD);

function  digest_dynamic(lib:p_lib_info):Integer;

procedure dynlibs_add_obj(lib:p_lib_info);

procedure init_relo_bits_process(lib:p_lib_info);

function  do_load_object(path:pchar):p_lib_info;
function  preload_prx_modules(const path:RawByteString):p_lib_info;

var
 dynlibs_info:t_dynlibs_info;

implementation

uses
 errno,
 systm,
 vm,
 vmparam,
 vm_map;

function scan_phdr(imgp:p_image_params;phdr:p_elf64_phdr;count:Integer):Integer;
var
 i:Integer;
 text_id     :Integer;
 data_id     :Integer;
 sce_relro_id:Integer;
 vaddr:QWORD;
 memsz:QWORD;
begin
 if (imgp=nil) then Exit(EINVAL);
 if (phdr=nil) then Exit(EINVAL);
 if (count=0)  then Exit(EINVAL);

 imgp^.min_addr:=High(Int64);
 imgp^.max_addr:=0;

 text_id     :=-1;
 data_id     :=-1;
 sce_relro_id:=-1;
 imgp^.dyn_id:=-1;

 if (count<>0) then
 For i:=0 to count-1 do
 begin

  case phdr[i].p_type of
   PT_LOAD,
   PT_SCE_RELRO:
     begin
      vaddr:=phdr[i].p_vaddr;

      if ((phdr[i].p_align and PAGE_MASK)<>0) or
         ((vaddr and PAGE_MASK)<>0) or
         ((phdr[i].p_offset and PAGE_MASK)<>0) then
      begin
       Writeln(StdErr,'scan_phdr:',imgp^.execpath,'segment #',i,' is not page aligned');
       Exit(ENOEXEC);
      end;

      memsz:=phdr[i].p_memsz;

      if (memsz<=phdr[i].p_filesz) and (phdr[i].p_filesz<>memsz) then
      begin
       Exit(ENOEXEC);
      end;

      if (memsz > $7fffffff) then
      begin
       Exit(ENOEXEC);
      end;

      if ((phdr[i].p_offset shr $20)<>0) then
      begin
       Exit(ENOEXEC);
      end;

      imgp^.min_addr:=MinInt64(imgp^.min_addr,vaddr);

      vaddr:=(vaddr+memsz+$3fff) and QWORD($ffffffffffffc000);

      imgp^.max_addr:=MaxInt64(imgp^.max_addr,vaddr);

      if (phdr[i].p_type=PT_SCE_RELRO) then
      begin
       sce_relro_id:=i;
      end else
      if ((phdr[i].p_flags and PF_X)=0) then
      begin
       if (data_id=-1) then data_id:=i;
      end else
      begin
       text_id:=i;
      end;
     end;

   PT_DYNAMIC:
     begin
      imgp^.dyn_exist :=1;
      imgp^.dyn_id    :=i;
      imgp^.dyn_vaddr :=Pointer(phdr[i].p_vaddr);
      imgp^.dyn_offset:=phdr[i].p_offset;
      imgp^.dyn_filesz:=phdr[i].p_filesz;

      memsz:=phdr[i].p_memsz;

      if (memsz<=phdr[i].p_filesz) and (phdr[i].p_filesz<>memsz) then
      begin
       Exit(ENOEXEC);
      end;

      if (memsz > $7fffffff) then
      begin
       Exit(ENOEXEC);
      end;

      if ((phdr[i].p_offset shr $20)<>0) then
      begin
       Exit(ENOEXEC);
      end;
     end;

   PT_TLS:
     begin
      imgp^.tls_size     :=phdr[i].p_memsz;
      imgp^.tls_align    :=phdr[i].p_align;
      imgp^.tls_init_size:=phdr[i].p_filesz;
      imgp^.tls_init_addr:=Pointer(phdr[i].p_vaddr);

      memsz:=phdr[i].p_memsz;

      if (memsz<=phdr[i].p_filesz) and (phdr[i].p_filesz<>memsz) then
      begin
       Exit(ENOEXEC);
      end;

      if (memsz > $7fffffff) then
      begin
       Exit(ENOEXEC);
      end;

      if ((phdr[i].p_offset shr $20)<>0) then
      begin
       Exit(ENOEXEC);
      end;

      if (phdr[i].p_align > 32) then
      begin
       Writeln(StdErr,'scan_phdr:',imgp^.execpath,'alignment of segment #',i,' it must be less than 32.');
       Exit(ENOEXEC);
      end;
     end;

   PT_SCE_DYNLIBDATA:
     begin
      imgp^.sce_dynlib_data_id  :=i;
      imgp^.sce_dynlib_data_addr:=phdr[i].p_offset;
      imgp^.sce_dynlib_data_size:=phdr[i].p_filesz;

      if (phdr[i].p_memsz<>0) then
      begin
       Exit(ENOEXEC);
      end;

      if (phdr[i].p_filesz > $7fffffff) then
      begin
       Exit(ENOEXEC);
      end;

      if ((phdr[i].p_offset shr $20)<>0) then
      begin
       Exit(ENOEXEC);
      end;
     end;

   PT_SCE_PROCPARAM:
     begin
      imgp^.proc_param_addr:=Pointer(phdr[i].p_vaddr);
      imgp^.proc_param_size:=phdr[i].p_filesz;
     end;

   PT_SCE_MODULE_PARAM:
     begin
      imgp^.module_param_addr:=Pointer(phdr[i].p_vaddr);
      imgp^.module_param_size:=phdr[i].p_filesz;
     end;

   PT_GNU_EH_FRAME:
    begin
     imgp^.eh_frame_hdr_addr:=Pointer(phdr[i].p_vaddr);
     imgp^.eh_frame_hdr_size:=phdr[i].p_memsz;

     memsz:=phdr[i].p_memsz;

     if (memsz<=phdr[i].p_filesz) and (phdr[i].p_filesz<>memsz) then
     begin
      Exit(ENOEXEC);
     end;

     if (memsz > $7fffffff) then
     begin
      Exit(ENOEXEC);
     end;

     if ((phdr[i].p_offset shr $20)<>0) then
     begin
      Exit(ENOEXEC);
     end;
    end;

   PT_SCE_COMMENT:
    begin
     imgp^.sce_comment_id    :=i;
     imgp^.sce_comment_offset:=phdr[i].p_offset;
     imgp^.sce_comment_filesz:=phdr[i].p_filesz;

     if (phdr[i].p_memsz<>0) then
     begin
      Exit(ENOEXEC);
     end;

     if (phdr[i].p_filesz > $7fffffff) then
     begin
      Exit(ENOEXEC);
     end;

     if ((phdr[i].p_offset shr $20)<>0) then
     begin
      Exit(ENOEXEC);
     end;
    end;

  end;

 end;

 if (imgp^.min_addr=High(Int64)) then
 begin
  Exit(EINVAL);
 end;

 if (imgp^.max_addr=0) then
 begin
  Exit(EINVAL);
 end;

 if (imgp^.dyn_exist<>0) then
 begin
  if (imgp^.sce_dynlib_data_size=0) then
  begin
   Exit(EINVAL);
  end;

  if (imgp^.dyn_filesz=0) then
  begin
   Exit(EINVAL);
  end;
 end;

 if (sce_relro_id<>-1) then
 begin
  vaddr:=phdr[sce_relro_id].p_vaddr;

  if (vaddr=0) then
  begin
   Exit(EINVAL);
  end;

  memsz:=phdr[sce_relro_id].p_memsz;

  if (memsz=0) then
  begin
   Exit(EINVAL);
  end;

  if (((phdr[text_id].p_vaddr+phdr[text_id].p_memsz+$1fffff) and $ffffffffffe00000)<>vaddr) and
     (((phdr[text_id].p_vaddr+phdr[text_id].p_memsz+$003fff) and $ffffffffffffc000)<>vaddr) then
  begin
   Exit(EINVAL);
  end;

  if (((vaddr+memsz+$1fffff) and $ffffffffffe00000)<>phdr[data_id].p_vaddr) and
     (((vaddr+memsz+$003fff) and $ffffffffffffc000)<>phdr[data_id].p_vaddr) then
  begin
   Exit(EINVAL);
  end;
 end;

 Result:=0;
end;

function trans_prot(flags:Elf64_Word):Byte;
begin
 Result:=0;
 if ((flags and PF_X)<>0) then Result:=Result or VM_PROT_EXECUTE;
 if ((flags and PF_W)<>0) then Result:=Result or VM_PROT_WRITE;
 if ((flags and PF_R)<>0) then Result:=Result or VM_PROT_READ;
end;

function obj_new():p_lib_info;
begin
 Result:=AllocMem(SizeOf(t_lib_info));

 TAILQ_INIT(@Result^.needed);
 TAILQ_INIT(@Result^.lib_table);
 //lib_modules
 TAILQ_INIT(@Result^.names);

 TAILQ_INIT(@Result^.dldags);
 TAILQ_INIT(@Result^.dagmembers);

 //Result^.rel_data:=(t_rel_data *)0x0;

 //puVar1:=&(Result^.rtld_flags).field_0x1;
 //*puVar1:=*puVar1 | 2;
end;

function elf64_get_eh_frame_info(hdr:p_eh_frame_hdr;
                                 hdr_size :QWORD;
                                 hdr_vaddr:QWORD;
                                 data_size:QWORD;
                                 eh_frame_addr:PPointer;
                                 eh_frame_size:PQWORD):Integer;
label
 __result;
var
 ret1:Integer;
 h,res,pos:PByte;
 enc:Byte;
 offset:QWORD;
 size:QWORD;
 fde_count:DWORD;
 _end:DWORD;
begin
 enc:=0;
 ret1:=copyin(@hdr^.eh_frame_ptr_enc,@enc,1);
 if (ret1<>0) then Exit(-1);

 h:=Pointer(hdr + 1);

 offset:=0;
 res:=nil;
 case enc of
  DW_EH_PE_udata4:
    begin
     ret1:=copyin(h,@offset,4);
     if (ret1<>0) then Exit(-1);

     res:=Pointer(Integer(offset) + hdr_vaddr);
    end;
  DW_EH_PE_pcrel or DW_EH_PE_sdata4:
    begin
     ret1:=copyin(h,@offset,4);
     if (ret1<>0) then Exit(-1);

     res:=h + Integer(offset);
    end;
  else
    Exit(-1)
 end;

 size:=0;
 if (res=nil) then
 begin
   __result:
   eh_frame_addr^:=res;
   eh_frame_size^:=size;
  Exit(0);
 end;

 fde_count:=0;
 ret1:=copyin(res,@fde_count,4);
 if (ret1<>0) then Exit(-1);

 pos:=res;
 size:=0;

 repeat

  offset:=fde_count;
  if (offset=$ffffffff) then
  begin
   ret1:=copyin(pos + 4,@offset,8);
   if (ret1<>0) then break;
   offset:=offset + 12;
  end else
  begin
   if (fde_count=0) then
   begin
    size:=size + 4;
    goto __result;
   end;
   offset:=offset + 4;
  end;

  _end:=offset + size;

  if (data_size <= (QWORD(res) + _end)) then goto __result;
  pos:=pos + offset;

  ret1:=copyin(pos,@fde_count,4);
  size:=_end;

 until (ret1<>0);

 Result:=-1;
end;

procedure _set_lib_path(lib:p_lib_info;path:PAnsiChar);
var
 size:int64;
begin
 size:=strlen(path);
 lib^.lib_path:=AllocMem(size+1);
 Move(path^,lib^.lib_path^,size);
end;

function preprocess_dt_entries(new:p_lib_info;hdr_e_type:Integer):Integer;
label
 _unsupp;
var
 dt_ent:p_elf64_dyn;
 i,count:Integer;

 SCE_SYMTABSZ         :Boolean;
 SCE_HASHSZ           :Boolean;
 SCE_SYMENT           :Boolean;
 SCE_SYMTAB           :Boolean;
 SCE_STRSZ            :Boolean;
 SCE_STRTAB           :Boolean;
 SCE_RELAENT          :Boolean;
 SCE_PLTREL           :Boolean;
 SCE_RELASZ           :Boolean;
 SCE_RELA             :Boolean;
 SCE_PLTRELSZ         :Boolean;
 SCE_JMPREL           :Boolean;
 SCE_PLTGOT           :Boolean;
 SCE_HASH             :Boolean;
 SCE_MODULE_INFO      :Boolean;
 SCE_ORIGINAL_FILENAME:Boolean;
 SCE_FINGERPRINT      :Boolean;
begin
 Result:=0;

 dt_ent:=new^.rel_data^.dynamic_addr;
 count :=new^.rel_data^.dynamic_size div sizeof(elf64_dyn);

 SCE_SYMTABSZ         :=False;
 SCE_HASHSZ           :=False;
 SCE_SYMENT           :=False;
 SCE_SYMTAB           :=False;
 SCE_STRSZ            :=False;
 SCE_STRTAB           :=False;
 SCE_RELAENT          :=False;
 SCE_PLTREL           :=False;
 SCE_RELASZ           :=False;
 SCE_RELA             :=False;
 SCE_PLTRELSZ         :=False;
 SCE_JMPREL           :=False;
 SCE_PLTGOT           :=False;
 SCE_HASH             :=False;
 SCE_MODULE_INFO      :=False;
 SCE_ORIGINAL_FILENAME:=False;
 SCE_FINGERPRINT      :=False;

 if (count<>0) then
 For i:=0 to count-1 do
 begin
  case dt_ent^.d_tag of
   DT_NULL,
   DT_NEEDED,
   DT_INIT,
   DT_FINI,
   DT_SONAME,
   DT_SYMBOLIC,
   DT_DEBUG,
   DT_TEXTREL,
   DT_INIT_ARRAY,
   DT_FINI_ARRAY,
   DT_INIT_ARRAYSZ,
   DT_FINI_ARRAYSZ,
   DT_FLAGS,
   DT_PREINIT_ARRAY,
   DT_PREINIT_ARRAYSZ,
   DT_SCE_NEEDED_MODULE,
   DT_SCE_MODULE_ATTR,
   DT_SCE_EXPORT_LIB,
   DT_SCE_IMPORT_LIB,
   DT_SCE_EXPORT_LIB_ATTR,
   DT_SCE_IMPORT_LIB_ATTR,
   DT_RELACOUNT,
   DT_FLAGS_1:; //ignore

   DT_PLTRELSZ,
   DT_SCE_PLTRELSZ:
     begin
      SCE_PLTRELSZ:=true;
      new^.rel_data^.pltrela_size:=dt_ent^.d_un.d_val;
     end;

   DT_PLTREL,
   DT_SCE_PLTREL:
     begin
      SCE_PLTREL:=true;
      if (dt_ent^.d_un.d_val<>7) then
      begin
       Writeln(StdErr,'preprocess_dt_entries:','illegal value in DT_PLTREL entry',' found in ',new^.lib_path);
       Exit(EINVAL);
      end;
     end;

   DT_RELASZ,
   DT_SCE_RELASZ:
     begin
      SCE_RELASZ:=true;
      new^.rel_data^.rela_size:=dt_ent^.d_un.d_val;
     end;

   DT_RELAENT,
   DT_SCE_RELAENT:
     begin
      SCE_RELAENT:=true;
      if (dt_ent^.d_un.d_val<>24) then
      begin
       Writeln(StdErr,'preprocess_dt_entries:','illegal value in DT_RELAENT entry',' found in ',new^.lib_path);
       Exit(EINVAL);
      end;
     end;

   DT_STRSZ,
   DT_SCE_STRSZ:
     begin
      SCE_STRSZ:=true;
      new^.rel_data^.strtab_size:=dt_ent^.d_un.d_val;
     end;

   DT_SYMENT,
   DT_SCE_SYMENT:
     begin
      SCE_SYMENT:=true;
      if (dt_ent^.d_un.d_val<>24) then
      begin
       Writeln(StdErr,'preprocess_dt_entries:','illegal value in DT_SYMENT entry',' found in ',new^.lib_path);
       Exit(EINVAL);
      end;
     end;

   DT_SCE_FINGERPRINT:
     begin
      SCE_FINGERPRINT:=true;
     end;

   DT_SCE_ORIGINAL_FILENAME:
     begin
      SCE_ORIGINAL_FILENAME:=true;
     end;

   DT_SCE_MODULE_INFO:
     begin
      SCE_MODULE_INFO:=true;
     end;

   DT_SCE_PLTGOT:
     begin
      SCE_PLTGOT:=true;
     end;

   DT_SCE_HASH:
     begin
      SCE_HASH:=true;
      new^.rel_data^.hash_addr:=Pointer(dt_ent^.d_un.d_val);
     end;

   DT_SCE_JMPREL:
     begin
      SCE_JMPREL:=true;
      new^.rel_data^.pltrela_addr:=Pointer(dt_ent^.d_un.d_val);
     end;

   DT_SCE_RELA:
     begin
      SCE_RELA:=true;
      new^.rel_data^.rela_addr:=Pointer(dt_ent^.d_un.d_val);
     end;

   DT_SCE_STRTAB:
     begin
      SCE_STRTAB:=true;
      new^.rel_data^.strtab_addr:=Pointer(dt_ent^.d_un.d_val);
     end;

   DT_SCE_SYMTAB:
     begin
      SCE_SYMTAB:=true;
      new^.rel_data^.symtab_addr:=Pointer(dt_ent^.d_un.d_val);
     end;

   DT_SCE_HASHSZ:
     begin
      SCE_HASHSZ:=true;
      new^.rel_data^.hash_size:=dt_ent^.d_un.d_val;
     end;

   DT_SCE_SYMTABSZ:
     begin
      SCE_SYMTABSZ:=true;
      new^.rel_data^.symtab_size:=dt_ent^.d_un.d_val;
     end;

   DT_PLTGOT,
   DT_RPATH,
   DT_BIND_NOW,
   DT_RUNPATH,
   DT_ENCODING,
   $61000008,
   $6100000a,
   $6100000b,
   $6100000c,
   $6100000e,
   $61000010,
   $61000012,
   $61000014,
   $61000016,
   $61000018,
   $6100001a,
   $6100001b,
   $6100001c,
   DT_SCE_STUB_MODULE_NAME,
   $6100001e,
   DT_SCE_STUB_MODULE_VERSION,
   $61000020,
   DT_SCE_STUB_LIBRARY_NAME,
   $61000022,
   DT_SCE_STUB_LIBRARY_VERSION,
   $61000024,
   $61000026,
   $61000028,
   $6100002a,
   $6100002c,
   $6100002e,
   $61000030,
   $61000032,
   $61000034,
   $61000036,
   $61000038,
   $6100003a,
   $6100003c,
   $6100003e:
     begin
      _unsupp:
      Writeln(StdErr,'preprocess_dt_entries:','Unsupported DT tag ',HexStr(dt_ent^.d_tag,8),' found in ',new^.lib_path);
      Exit(ENOEXEC);
     end;

   DT_HASH,
   DT_STRTAB,
   DT_SYMTAB,
   DT_RELA,
   DT_JMPREL:
     begin
      Writeln(StdErr,'preprocess_dt_entries:','ORBIS object file does not support DT tag ',HexStr(dt_ent^.d_tag,8),' found in ',new^.lib_path);
      Exit(EINVAL);
     end;

   else
     goto _unsupp;
  end;

  Inc(dt_ent);
 end;

 if (SCE_HASHSZ) and (SCE_SYMTABSZ) then
 begin
   if  ( (hdr_e_type=ET_SCE_DYNAMIC) and ((not SCE_ORIGINAL_FILENAME) or (not SCE_MODULE_INFO)) ) or
       (not SCE_FINGERPRINT) or
       (not SCE_HASH) or
       (not SCE_PLTGOT) or
       (not SCE_JMPREL) or
       (not SCE_PLTREL) or
       (not SCE_PLTRELSZ) or
       (not SCE_RELA) or
       (not SCE_RELASZ) or
       (not SCE_RELAENT) or
       (not SCE_STRTAB) or
       (not SCE_STRSZ) or
       (not SCE_SYMTAB) or
       (not SCE_SYMENT) then
   begin
    Writeln(StdErr,'preprocess_dt_entries:',new^.lib_path,' does not have required tabs.');
    Exit(EINVAL);
   end;
 end else
 begin
  Writeln(StdErr,'preprocess_dt_entries:',new^.lib_path,' does not have DT_SCE_SYMTABSZ or DT_SCE_HASHSZ tabs.');
  Exit(EINVAL);
 end;

end;

procedure release_per_file_info_obj(lib:p_lib_info);
begin
 if (lib^.rel_data<>nil) then
 begin
  FreeMem(lib^.rel_data);
  lib^.rel_data:=nil;
 end;
end;

function acquire_per_file_info_obj(imgp:p_image_params;new:p_lib_info):Integer;
var
 full_size:QWORD;
 src,dst:Pointer;
begin
 Result:=0;

 if (imgp^.dyn_exist=0) then Exit(EINVAL);

 full_size:=sizeOf(t_rel_data)+1+
            AlignUp(imgp^.sce_dynlib_data_size,8)+
            AlignUp(imgp^.sce_comment_filesz,8)+
            strlen(imgp^.execpath);

 new^.rel_data:=AllocMem(full_size);

 dst:=Pointer(new^.rel_data+1);

 src:=Pointer(imgp^.image_header)+imgp^.sce_dynlib_data_addr;

 Move(src^,dst^,imgp^.sce_dynlib_data_size);

 new^.rel_data^.sce_dynlib_addr:=dst;
 new^.rel_data^.sce_dynlib_size:=imgp^.sce_dynlib_data_size;

 dst:=dst+AlignUp(imgp^.sce_dynlib_data_size,8);

 if (imgp^.sce_comment_filesz<>0) then
 begin
  src:=Pointer(imgp^.image_header)+imgp^.sce_comment_offset;

  Move(src^,dst^,imgp^.sce_comment_filesz);

  new^.rel_data^.sce_comment_addr:=dst;
  new^.rel_data^.sce_comment_size:=imgp^.sce_comment_filesz;

  dst:=dst+AlignUp(imgp^.sce_comment_filesz,8);
 end;

 Move(imgp^.execpath^,dst^,sizeOf(t_rel_data)+1);

 new^.rel_data^.execpath:=dst;

 src:=new^.rel_data^.sce_dynlib_addr;

 new^.rel_data^.dynamic_addr:=src+imgp^.dyn_offset;
 new^.rel_data^.dynamic_size:=imgp^.dyn_filesz;

 Result:=preprocess_dt_entries(new,imgp^.hdr_e_type);

 if (Result<>0) then
 begin
  FreeMem(new^.rel_data);
  new^.rel_data:=nil;
  Exit;
 end;

 src:=new^.rel_data^.sce_dynlib_addr;

 new^.rel_data^.symtab_addr :=Pointer(QWORD(src)+QWORD(new^.rel_data^.symtab_addr ));
 new^.rel_data^.strtab_addr :=Pointer(QWORD(src)+QWORD(new^.rel_data^.strtab_addr ));
 new^.rel_data^.pltrela_addr:=Pointer(QWORD(src)+QWORD(new^.rel_data^.pltrela_addr));
 new^.rel_data^.rela_addr   :=Pointer(QWORD(src)+QWORD(new^.rel_data^.rela_addr   ));
 new^.rel_data^.hash_addr   :=Pointer(QWORD(src)+QWORD(new^.rel_data^.hash_addr   ));

 src:=new^.rel_data^.hash_addr;

 new^.rel_data^.hashsize    :=PDWORD(src)^;
 new^.rel_data^.buckets_size:=new^.rel_data^.hashsize shl 2;

 new^.rel_data^.buckets    :=Pointer(QWORD(src) + 8);
 new^.rel_data^.dynsymcount:=PDWORD (QWORD(src) + 4)^;
 new^.rel_data^.chains_size:=new^.rel_data^.dynsymcount shl 2;

 new^.rel_data^.chains:=Pointer(QWORD(src) + (new^.rel_data^.hashsize + 2) * 4);

end;

procedure free_tls_offset(lib:p_lib_info);
begin
 if (lib^.tls_done<>0) and (lib^.tls_offset=dynlibs_info.tls_last_offset) then
 begin
  dynlibs_info.tls_last_offset:=lib^.tls_offset - lib^.tls_size;
  dynlibs_info.tls_last_size  :=0;
 end;
end;

procedure obj_free(lib:p_lib_info);
var
 needed:p_Needed_Entry;
 names:p_Name_Entry;
 dag:p_Objlist_Entry;
 libs:p_Lib_Entry;
begin

 free_tls_offset(lib);

 needed:=TAILQ_FIRST(@lib^.needed);
 while (needed<>nil) do
 begin
  TAILQ_REMOVE(@lib^.needed,needed,@needed^.link);
  FreeMem(needed);
  needed:=TAILQ_FIRST(@lib^.needed);
 end;

 names:=TAILQ_FIRST(@lib^.names);
 while (names<>nil) do
 begin
  TAILQ_REMOVE(@lib^.names,names,@names^.link);
  FreeMem(names);
  names:=TAILQ_FIRST(@lib^.names);
 end;

 dag:=TAILQ_FIRST(@lib^.dldags);
 while (dag<>nil) do
 begin
  TAILQ_REMOVE(@lib^.dldags,dag,@dag^.link);
  FreeMem(dag);
  dag:=TAILQ_FIRST(@lib^.dldags);
 end;

 dag:=TAILQ_FIRST(@lib^.dagmembers);
 while (dag<>nil) do
 begin
  TAILQ_REMOVE(@lib^.dagmembers,dag,@dag^.link);
  FreeMem(dag);
  dag:=TAILQ_FIRST(@lib^.dagmembers);
 end;

 if (lib^.lib_dirname<>nil) then
 begin
  FreeMem(lib^.lib_dirname);
  lib^.lib_dirname:=nil;
 end;

 if (lib^.lib_path<>nil) then
 begin
  FreeMem(lib^.lib_path);
  lib^.lib_path:=nil;
 end;

 if (lib^.relo_bits_process<>nil) then
 begin
  FreeMem(lib^.relo_bits_process);
  lib^.relo_bits_process:=nil
 end;

 libs:=TAILQ_FIRST(@lib^.lib_table);
 while (libs<>nil) do
 begin
  TAILQ_REMOVE(@lib^.lib_table,libs,@libs^.link);
  FreeMem(libs);
  libs:=TAILQ_FIRST(@lib^.lib_table);
 end;

 release_per_file_info_obj(lib);

 FreeMem(lib);
end;

function obj_get_str(lib:p_lib_info;offset:Int64):pchar;
begin
 if (lib^.rel_data^.strtab_size<=offset) then
 begin
  Writeln(StdErr,'obj_get_str:','offset=',HexStr(offset,8),' is out of range of string table of ',lib^.lib_path);
  Exit(nil);
 end;

 Result:=lib^.rel_data^.strtab_addr+offset;
end;

procedure object_add_name(obj:p_lib_info;name:pchar);
var
 len:Integer;
 entry:p_Name_Entry;
begin
 len:=strlen(name);
 entry:=AllocMem(SizeOf(Name_Entry)+len);
 Move(name^,entry^.name,len);
 //
 TAILQ_INSERT_TAIL(@obj^.names,entry,@entry^.link);
end;

function object_match_name(obj:p_lib_info;name:pchar):Boolean;
var
 entry:p_Name_Entry;
begin
 entry:=TAILQ_FIRST(@obj^.names);
 while (entry<>nil) do
 begin
  if (StrComp(name,@entry^.name)=0) then
  begin
   Exit(True);
  end;
 end;
 Result:=False;
end;

function Needed_new(lib:p_lib_info;str:pchar):p_Needed_Entry;
var
 len:Integer;
begin
 len:=strlen(str);
 Result:=AllocMem(SizeOf(Needed_Entry)+len);
 Result^.obj :=lib;
 Move(str^,Result^.name,len);
end;

function Lib_new(d_tag:DWORD;d_val:QWORD):p_Lib_Entry;
begin
 Result:=AllocMem(SizeOf(Lib_Entry));
 QWORD(Result^.dval):=d_val;
 Result^.export:=ord(d_tag=DT_SCE_IMPORT_LIB);
end;

procedure initlist_add_objects(var fini_proc_list:TAILQ_HEAD;
                               obj :p_lib_info;
                               tail:p_lib_info;
                               var init_proc_list:TAILQ_HEAD);
var
 proc_entry:p_Objlist_Entry;
begin
 if (obj^.init_scanned<>0) or (obj^.init_done<>0) then Exit;
 obj^.init_scanned:=1;

 if (obj<>tail) then
 begin
  initlist_add_objects(fini_proc_list,obj^.entry.tqe_next,tail,init_proc_list);
 end;

 if (obj^.needed.tqh_first<>nil) then
 begin
  initlist_add_neededs(fini_proc_list,obj^.needed.tqh_first,init_proc_list);
 end;

 if (obj^.init_proc_addr<>nil) then
 begin
  proc_entry:=AllocMem(SizeOf(Objlist_Entry));

  proc_entry^.obj:=obj;

  TAILQ_INSERT_TAIL(@init_proc_list,proc_entry,@proc_entry^.link);
 end;

 if (obj^.fini_proc_addr<>nil) and (obj^.init_fini=0) then
 begin
  proc_entry:=AllocMem(SizeOf(Objlist_Entry));

  proc_entry^.obj:=obj;

  TAILQ_INSERT_TAIL(@fini_proc_list,proc_entry,@proc_entry^.link);

  obj^.init_fini:=1;
 end;
end;

procedure initlist_add_neededs(var fini_proc_list:TAILQ_HEAD;
                               needed:p_Needed_Entry;
                               var init_proc_list:TAILQ_HEAD);
var
 obj:p_lib_info;
begin
 if (needed^.link.tqe_next<>nil) then
 begin
  initlist_add_neededs(fini_proc_list,needed^.link.tqe_next,init_proc_list);
 end;

 obj:=needed^.obj;
 if (obj<>nil) then
 begin
  initlist_add_objects(fini_proc_list,obj,obj,init_proc_list);
 end;
end;


function digest_dynamic(lib:p_lib_info):Integer;
var
 dt_ent:p_elf64_dyn;
 i,count:Integer;

 str:pchar;

 needed:p_Needed_Entry;
 lib_entry:p_Lib_Entry;

 addr:Pointer;
 dval:QWORD;

 dyn_soname:p_elf64_dyn;
 dt_fingerprint:Int64;
begin
 Result:=0;

 dyn_soname:=nil;
 dt_fingerprint:=-1;

 if (lib^.rel_data<>nil) then
 begin
  dt_ent:=lib^.rel_data^.dynamic_addr;
  count :=lib^.rel_data^.dynamic_size div sizeof(elf64_dyn);

  if (count<>0) then
  For i:=0 to count-1 do
  begin

   case dt_ent^.d_tag of
    DT_NULL,
    DT_PLTRELSZ,
    DT_HASH,
    DT_STRTAB,
    DT_SYMTAB,
    DT_RELA,
    DT_RELASZ,
    DT_RELAENT,
    DT_STRSZ,
    DT_SYMENT,
    DT_PLTREL,
    DT_DEBUG,
    DT_JMPREL,
    DT_INIT_ARRAY,
    DT_FINI_ARRAY,
    DT_INIT_ARRAYSZ,
    DT_FINI_ARRAYSZ,
    DT_PREINIT_ARRAY,
    DT_PREINIT_ARRAYSZ,
    DT_SCE_HASH,
    DT_SCE_JMPREL,
    DT_SCE_PLTREL,
    DT_SCE_PLTRELSZ,
    DT_SCE_RELA,
    DT_SCE_RELASZ,
    DT_SCE_RELAENT,
    DT_SCE_STRTAB,
    DT_SCE_STRSZ,
    DT_SCE_SYMTAB,
    DT_SCE_SYMENT,
    DT_SCE_HASHSZ,
    DT_SCE_SYMTABSZ,
    DT_RELACOUNT:;  //ignore

    DT_SONAME:
     begin
      dyn_soname:=dt_ent;
     end;

    DT_PLTGOT,
    DT_SCE_PLTGOT:
     begin
      //pltgot
     end;

    DT_NEEDED:
      begin
       str:=obj_get_str(lib,dt_ent^.d_un.d_val);

       if (str=nil) then
       begin
        Writeln(StdErr,'digest_dynamic:',{$INCLUDE %LINE%});
        Exit(EINVAL);
       end;

       needed:=Needed_new(lib,str);
       TAILQ_INSERT_TAIL(@lib^.needed,needed,@Needed^.link);
      end;

    DT_INIT:
      begin
       addr:=lib^.relocbase+dt_ent^.d_un.d_val;
       lib^.init_proc_addr:=addr;

       if (lib^.map_base>addr) or ((addr+8)>(lib^.map_base+lib^.text_size)) then
       begin
        Writeln(StdErr,'digest_dynamic:',{$INCLUDE %LINE%});
        Exit(ENOEXEC);
       end;
      end;

    DT_FINI:
      begin
       addr:=lib^.relocbase+dt_ent^.d_un.d_val;
       lib^.fini_proc_addr:=addr;

       if (lib^.map_base>addr) or ((addr+8)>(lib^.map_base+lib^.text_size)) then
       begin
        Writeln(StdErr,'digest_dynamic:',{$INCLUDE %LINE%});
        Exit(ENOEXEC);
       end;
      end;

    DT_SYMBOLIC:
      begin
       Writeln(StdErr,'digest_dynamic:','DT_SYMBOLIC is obsolete.');
       Exit(EINVAL);
      end;

    DT_TEXTREL:
      begin
       lib^.textrel:=1;
      end;

    DT_FLAGS:
      begin
       dval:=dt_ent^.d_un.d_val;

       if ((dval and DF_SYMBOLIC)<>0) then
       begin
        Writeln(StdErr,'digest_dynamic:','DT_SYMBOLIC is obsolete.');
        Exit(EINVAL);
       end;

       if ((dval and DF_BIND_NOW)<>0) then
       begin
        Writeln(StdErr,'digest_dynamic:','DF_BIND_NOW is obsolete.');
        Exit(EINVAL);
       end;

       if ((dval and DF_TEXTREL)<>0) then
       begin
        lib^.textrel:=1;
       end;
      end;

    DT_SCE_FINGERPRINT:
      begin
       dt_fingerprint:=dt_ent^.d_un.d_val;

       if (lib^.rel_data=nil) or
          ((dt_fingerprint + 20)>lib^.rel_data^.sce_dynlib_size) then
       begin
        Writeln(StdErr,'digest_dynamic:',{$INCLUDE %LINE%});
        Exit(ENOEXEC);
       end;
      end;

    DT_SCE_ORIGINAL_FILENAME:
      begin
       str:=obj_get_str(lib,dt_ent^.d_un.d_val);

       if (str=nil) then
       begin
        Writeln(StdErr,'digest_dynamic:',{$INCLUDE %LINE%});
        Exit(EINVAL);
       end;

       lib^.rel_data^.original_filename:=str;
      end;

    DT_SCE_MODULE_INFO,
    DT_SCE_NEEDED_MODULE:
      begin
       //need_module
      end;

    DT_SCE_MODULE_ATTR:
      begin
       //dval
      end;

    DT_SCE_EXPORT_LIB,
    DT_SCE_IMPORT_LIB:
      begin
       lib_entry:=Lib_new(dt_ent^.d_tag,dt_ent^.d_un.d_val);
       TAILQ_INSERT_TAIL(@lib^.lib_table,lib_entry,@lib_entry^.link);
      end;

    DT_SCE_EXPORT_LIB_ATTR,
    DT_SCE_IMPORT_LIB_ATTR:
      begin
       dval:=dt_ent^.d_un.d_val;

       lib_entry:=lib^.lib_table.tqh_first;
       while (lib_entry<>nil) do
       begin
        if (TLibraryAttr(dval).id=lib_entry^.dval.id) then
        begin
         Break;
        end;
        lib_entry:=lib_entry^.link.tqe_next;
       end;

       if (lib_entry=nil) then
       begin
        Writeln(StdErr,'digest_dynamic:','unknown ID found in DT_SCE_*_LIB_ATTR entry ',TLibraryAttr(dval).id);
        Exit(EINVAL);
       end;

       lib_entry^.attr:=TLibraryAttr(dval).attr;
      end;

    DT_FLAGS_1:
      begin
       dval:=dt_ent^.d_un.d_val;

       if ((dval and DF_1_BIND_NOW)<>0) then
       begin
        Writeln(StdErr,'digest_dynamic:','DF_1_BIND_NOW is obsolete.');
        Exit(EINVAL);
       end;

       if ((dval and DF_1_NODELETE)<>0) then
       begin
        Writeln(StdErr,'digest_dynamic:','DF_1_NODELETE is obsolete.');
        Exit(EINVAL);
       end;

       if ((dval and DF_1_LOADFLTR)<>0) then
       begin
        Writeln(StdErr,'digest_dynamic:','DF_1_LOADFLTR is obsolete.');
        Exit(EINVAL);
       end;

       if ((dval and DF_1_NOOPEN)<>0) then
       begin
        Writeln(StdErr,'digest_dynamic:','DF_1_NOOPEN is obsolete.');
        Exit(EINVAL);
       end;
      end;

    else
      begin
       Writeln(StdErr,'digest_dynamic:','Unsupported DT tag ',HexStr(dt_ent^.d_tag,8),' found in ',lib^.lib_path);
       Exit(ENOEXEC);
      end;

   end; //case

   Inc(dt_ent);
  end; //for

 end;

 addr:=lib^.rel_data^.sce_dynlib_addr;

 if (dt_fingerprint=-1) then
 begin
  if (addr<>nil) then
  begin
   Move(addr^,lib^.fingerprint,20);
  end;
 end else
 begin
  if (addr<>nil) then
  begin
   Move((addr+dt_fingerprint)^,lib^.fingerprint,20);
  end;
 end;

 if (lib^.lib_path<>nil) then
 begin
  lib^.lib_dirname:=AllocMem(strlen(lib^.lib_path)+1);
  //
  Result:=rtld_dirname(lib^.lib_path,lib^.lib_dirname);
  if (Result<>0) then
  begin
   Exit(EINVAL);
  end;
 end;

 if (dyn_soname<>nil) then
 begin
  str:=obj_get_str(lib,dyn_soname^.d_un.d_val);

  if (str=nil) then
  begin
   Writeln(StdErr,'digest_dynamic:',{$INCLUDE %LINE%});
   Exit(EINVAL);
  end;

  object_add_name(lib,str);
 end;

end;

procedure dynlibs_add_obj(lib:p_lib_info);
begin
 TAILQ_INSERT_TAIL(@dynlibs_info.lib_list,lib,@lib^.entry);
 Inc(dynlibs_info.obj_count);
end;

procedure init_relo_bits_process(lib:p_lib_info);
var
 count:Integer;
begin
 if (lib^.rel_data=nil) then
 begin
  count:=0;
 end else
 begin
  count:=(lib^.rel_data^.pltrela_size div sizeof(elf64_rela))+(lib^.rel_data^.rela_size div sizeof(elf64_rela));
 end;

 lib^.relo_bits_process:=AllocMem((count+7) div 8);
end;

function self_load_shared_object(path:pchar;new:p_lib_info):Integer;
begin
 Result:=-1;

 //////////
end;

function do_load_object(path:pchar):p_lib_info;
label
 _inc_max,
 _error;
var
 fname:RawByteString;
 new:p_lib_info;
 lib:p_lib_info;
 i,err:Integer;
 tls_max:Integer;
 map_base:Pointer;
 map_size:QWORD;
 map:vm_map_t;
begin
 Result:=nil;

 new:=obj_new();

 err:=self_load_shared_object(path,new);
 if (err<>0) then
 begin
  goto _error;
 end;

 fname:=ExtractFileName(path);
 object_add_name(new,pchar(fname));

 _set_lib_path(new,path);

 if (new^.tls_size=0) then
 begin
  i:=0;
 end else
 begin
  dynlibs_info.tls_count:=dynlibs_info.tls_count + 1;
  tls_max:=dynlibs_info.tls_max;

  if (tls_max<1) then
  begin
   _inc_max:
   i:=tls_max+1;
   dynlibs_info.tls_max:=i;
  end else
  begin
   i:=1;
   lib:=TAILQ_FIRST(@dynlibs_info.lib_list);
   while (lib<>nil) do
   begin
    while (lib^.tls_index=i) do
    begin
     i:=i+1;
     lib:=TAILQ_FIRST(@dynlibs_info.lib_list);
     if (tls_max < i) then
     begin
      goto _inc_max;
     end;
    end;
    lib:=TAILQ_NEXT(lib,@lib^.entry);
   end;
  end;
 end;

 new^.tls_index:=i;

 err:=digest_dynamic(new);
 if (err<>0) then
 begin
  Writeln(StdErr,'do_load_object:','digest_dynamic() failed rv=',err);
  goto _error;
 end;

 //err:=dynlib_initialize_pltgot_each(new);
 if (err<>0) then
 begin
  Writeln(StdErr,'do_load_object:','dynlib_initialize_pltgot_each() failed rv=',err);
  goto _error;
 end;

 if (new^.textrel<>0) then
 begin
  Writeln(StdErr,'do_load_object:',new^.lib_path,' has impure text');
  err:=EINVAL;
  goto _error;
 end;

 init_relo_bits_process(lib);
 dynlibs_add_obj(new);
 new^.loaded:=1;
 Exit(new);

 _error:

 map_base:=new^.map_base;
 map_size:=new^.map_size;

 if (map_base<>nil) then
 begin
  map:=@g_vmspace.vm_map;

  vm_map_lock(map);
  vm_map_delete(map,QWORD(map_base),QWORD(map_base) + map_size);
  vm_map_unlock(map);
 end;

 obj_free(new);

 Exit(nil);
end;

function preload_prx_modules(const path:RawByteString):p_lib_info;
label
 _do_load;
var
 lib:p_lib_info;
 fname:RawByteString;
begin
 Result:=nil;

 fname:=ExtractFileName(path);

 lib:=TAILQ_FIRST(@dynlibs_info.lib_list);
 while (lib<>nil) do
 begin
  if object_match_name(lib,pchar(fname)) then
  begin
   Exit(lib);
  end;
  lib:=TAILQ_NEXT(lib,@lib^.entry);
 end;

 fname:=path;
 if (fname[1]='/') then //relative?
 begin
  fname:=p_proc.p_randomized_path+fname;
 end;

 if rtld_file_exists(pchar(fname)) then goto _do_load;

 fname:=ChangeFileExt(fname,'.sprx');
 if rtld_file_exists(pchar(fname)) then goto _do_load;

 fname:=ChangeFileExt(fname,'.prx');
 if rtld_file_exists(pchar(fname)) then goto _do_load;

 Exit(nil);
 _do_load:

 Result:=do_load_object(pchar(fname));
end;

end.
