unit kern_rtld;

{$mode ObjFPC}{$H+}
{$CALLING SysV_ABI_CDecl}

interface

uses
 sysutils,
 kern_thr,
 vfile,
 vnode,
 vm_object,
 vuio,
 elf64;

const
 AT_NULL        = 0; // Terminates the vector.
 AT_IGNORE      = 1; // Ignored entry.
 AT_EXECFD      = 2; // File descriptor of program to load.
 AT_PHDR        = 3; // Program header of program already loaded.
 AT_PHENT       = 4; // Size of each program header entry.
 AT_PHNUM       = 5; // Number of program header entries.
 AT_PAGESZ      = 6; // Page size in bytes.
 AT_BASE        = 7; // Interpreter's base address.
 AT_FLAGS       = 8; // Flags (unused for i386).
 AT_ENTRY       = 9; // Where interpreter should transfer control.
 AT_NOTELF      =10; // Program is not ELF ??
 AT_UID         =11; // Real uid.
 AT_EUID        =12; // Effective uid.
 AT_GID         =13; // Real gid.
 AT_EGID        =14; // Effective gid.
 AT_EXECPATH    =15; // Path to the executable.
 AT_CANARY      =16; // Canary for SSP
 AT_CANARYLEN   =17; // Length of the canary.
 AT_OSRELDATE   =18; // OSRELDATE.
 AT_NCPUS       =19; // Number of CPUs.
 AT_PAGESIZES   =20; // Pagesizes.
 AT_PAGESIZESLEN=21; // Number of pagesizes.
 AT_TIMEKEEP    =22; // Pointer to timehands.
 AT_STACKPROT   =23; // Initial stack protection.

 AT_COUNT       =24; // Count of defined aux entry types.

 ARG_MAX=262144; // max bytes for an exec function

 ps_arg_cache_limit=$400;

type
 p_ps_strings=^t_ps_strings;
 t_ps_strings=packed record
  ps_argvstr :ppchar;  //first of 0 or more argument string
  ps_nargvstr:Integer; //the number of argument strings
  _align1    :Integer; //
  ps_envstr  :ppchar;  //first of 0 or more environment strings
  ps_nenvstr :Integer; //the number of environment strings
  _align2    :Integer; //
 end;
 {$IF sizeof(t_ps_strings)<>32}{$STOP sizeof(t_ps_strings)<>32}{$ENDIF}

 p_image_args=^t_image_args;
 t_image_args=packed record
  buf        :PChar;   //pointer to string buffer
  begin_argv :PChar;   //beginning of argv in buf
  begin_envv :PChar;   //beginning of envv in buf
  endp       :PChar;   //current `end' pointer of arg & env strings
  fname      :PChar;   //pointer to filename of executable (system space)
  fname_buf  :PChar;   //pointer to optional malloc(M_TEMP) buffer
  stringspace:Integer; //space left in arg & env buffer
  argc       :Integer; //count of argument strings
  envc       :Integer; //count of environment strings
  fd         :Integer; //file descriptor of the executable
 end;

 p_elf64_auxargs=^t_elf64_auxargs;
 t_elf64_auxargs=packed record
  execfd:Int64;
  phdr  :QWORD;
  phent :QWORD;
  phnum :QWORD;
  pagesz:QWORD;
  base  :QWORD;
  flags :QWORD;
  entry :QWORD;
 end;

 p_authinfo=^t_authinfo;
 t_authinfo=packed record
  app_type_id:QWORD;
  app_flags  :QWORD;
  app_cap    :QWORD;
  unknow1    :array[0..1] of QWORD;
  s_prog_attr:QWORD;
  unknow2    :array[0..10] of QWORD;
 end;
 {$IF sizeof(t_authinfo)<>136}{$STOP sizeof(t_authinfo)<>136}{$ENDIF}

 p_image_params=^t_image_params;
 t_image_params=packed record
  vp          :p_vnode;
  obj         :vm_object_t;
  attr        :p_vattr;
  image_self  :p_self_header;
  image_header:p_elf64_hdr;
  entry_addr  :Pointer;
  reloc_base  :Pointer;
  opened      :Integer;
  elf_size    :Integer;
  auxargs     :p_elf64_auxargs;
  auxarg_size :QWORD;
  args        :p_image_args;
  execpath    :PChar;
  execpathp   :Pointer;
  freepath    :PChar;
  canary      :Pointer;
  pagesizes   :Pointer;
  canarylen   :Integer;
  pagesizeslen:Integer;

  dyn_vaddr:p_elf64_dyn;

  tls_size     :QWORD;
  tls_align    :QWORD;
  tls_init_size:QWORD;
  tls_init_addr:Pointer;

  eh_frame_hdr_addr:Pointer;
  eh_frame_hdr_size:QWORD;

  authinfo:t_authinfo;

  proc_param_addr:pSceProcParam;
  proc_param_size:QWORD;

  module_param_addr:psceModuleParam;
  module_param_size:QWORD;

  dyn_id            :Integer;
  sce_dynlib_data_id:Integer;
  sce_comment_id    :Integer;
  dyn_exist         :Integer;

  dyn_offset          :QWORD;
  dyn_filesz          :QWORD;

  sce_dynlib_data_addr:QWORD;
  sce_dynlib_data_size:QWORD;

  sce_comment_offset  :QWORD;
  sce_comment_filesz  :QWORD;

  min_addr:QWORD;
  max_addr:QWORD;

  relro_addr:Pointer;
  relro_size:QWORD;

  hdr_e_type:Integer;
 end;

const
 M2MB_NOTDYN_FIXED=0; //Default    =0     (ATTRIBUTE2:0x00000)
 M2MB_DISABLE     =1; //NotUsed    =32768 (ATTRIBUTE2:0x08000)
 M2MB_READONLY    =2; //Text_rodata=65536 (ATTRIBUTE2:0x10000)
 M2MB_ENABLE      =3; //All_section=98304 (ATTRIBUTE2:0x18000)

 g_self_fixed:Integer=0;
 g_mode_2mb  :Integer=M2MB_NOTDYN_FIXED;
 budget_ptype_caller:Integer=0;

function  maxInt64(a,b:Int64):Int64; inline;
function  minInt64(a,b:Int64):Int64; inline;

function  get_elf_phdr(elf_hdr:p_elf64_hdr):p_elf64_phdr; inline;
procedure exec_load_free(imgp:p_image_params);
function  exec_load_self(imgp:p_image_params):Integer;
procedure exec_load_authinfo(imgp:p_image_params);

function  is_used_mode_2mb(phdr:p_elf64_phdr;is_dynlib,budget_ptype_caller:Integer):Boolean;

function  rtld_dirname(path,bname:pchar):Integer;
function  rtld_file_exists(path:pchar):Boolean;

implementation

uses
 errno,
 vnamei,
 vfs_lookup,
 vfs_subr,
 vnode_if;

function maxInt64(a,b:Int64):Int64; inline;
begin
 if (a>b) then Result:=a else Result:=b;
end;

function minInt64(a,b:Int64):Int64; inline;
begin
 if (a<b) then Result:=a else Result:=b;
end;

function get_elf_phdr(elf_hdr:p_elf64_hdr):p_elf64_phdr; inline;
begin
 Result:=Pointer(elf_hdr+1);
end;

function get_elf_phdr_offset(elf_hdr:p_elf64_hdr):Int64; inline;
begin
 Result:=SizeOf(elf64_hdr);
end;

procedure fixup_offset_size(var offset,size:Int64;max:Int64);
var
 s,e:Int64;
begin
 s:=offset;
 e:=s+size;

 s:=MinInt64(s,max);
 e:=MinInt64(e,max);

 offset:=s;
 size  :=(e-s);
end;

function kread(vp:p_vnode;buf:Pointer;nbyte,offset:Integer):Integer;
var
 uio:t_uio;
 aio:iovec;
begin
 uio:=Default(t_uio);
 aio:=Default(iovec);
 //
 aio.iov_base  :=buf;
 aio.iov_len   :=nbyte;
 //
 uio.uio_iov   :=@aio;
 uio.uio_iovcnt:=1;
 uio.uio_offset:=offset;
 uio.uio_segflg:=UIO_SYSSPACE;
 uio.uio_rw    :=UIO_READ;
 uio.uio_resid :=nbyte;
 uio.uio_td    :=curkthread;
 //
 Result:=VOP_READ(vp,@uio,0);

 if (Result=0) then
 begin
  if (uio.uio_resid<>0) then
  begin
   Result:=ENOEXEC;
  end;
 end;
end;

procedure exec_load_free(imgp:p_image_params);
begin
 FreeMem(imgp^.image_header);
 FreeMem(imgp^.image_self);
 imgp^.image_header:=nil;
 imgp^.image_self:=nil;
 imgp^.elf_size:=0;
end;

function exec_load_self(imgp:p_image_params):Integer;
Var
 vp:p_vnode;
 obj_size:Int64;
 n,s:Int64;
 Magic:DWORD;
 i,count:Integer;
 self_hdr :p_self_header;
 self_segs:p_self_segment;
 elf_hdr  :p_elf64_hdr;
 elf_phdr :p_elf64_phdr;
 MinSeg   :Int64;
 MaxSeg   :Int64;
 src_ofs  :Int64;
 dst_ofs  :Int64;
 mem_size :Int64;
begin
 Result:=0;

 if (imgp=nil) then Exit(EINVAL);

 vp:=imgp^.vp;
 obj_size:=imgp^.attr^.va_size;

 if (obj_size=0) then Exit(ENOEXEC);

 Result:=kread(vp,@Magic,SizeOf(DWORD),0);
 if (Result<>0) then Exit;

 case Magic of
  ELFMAG: //elf64
    begin
      elf_hdr:=AllocMem(obj_size);

      Result:=kread(vp,elf_hdr,obj_size,0);
      if (Result<>0) then
      begin
       FreeMem(elf_hdr);
       Exit;
      end;

      imgp^.image_header:=elf_hdr;
      imgp^.image_self  :=nil;
      imgp^.elf_size    :=obj_size;
    end;
  SELF_MAGIC: //self
    begin
      self_hdr:=AllocMem(obj_size);

      Result:=kread(vp,self_hdr,obj_size,0);
      if (Result<>0) then
      begin
       FreeMem(self_hdr);
       Exit;
      end;

      if (self_hdr^.File_size>obj_size) then
      begin
       FreeMem(self_hdr);
       Exit(EFAULT);
      end;

      count:=self_hdr^.Num_Segments;

      if (count=0) then
      begin
       FreeMem(self_hdr);
       Exit(ENOEXEC);
      end;

      self_segs:=Pointer(self_hdr+1);

      For i:=0 to count-1 do
       if ((self_segs[i].flags and (SELF_PROPS_ENCRYPTED or SELF_PROPS_COMPRESSED))<>0) then
       begin
        Writeln(StdErr,'exec_load_self:',imgp^.execpath,'is encrypted!');
        FreeMem(self_hdr);
        Exit(ENOEXEC);
       end;

      elf_hdr:=Pointer(self_segs)+(count*SizeOf(t_self_segment));

      elf_phdr:=get_elf_phdr(elf_hdr);

      MinSeg:=High(Int64);
      MaxSeg:=0;

      count:=self_hdr^.Num_Segments;

      For i:=0 to count-1 do
       if ((self_segs[i].flags and SELF_PROPS_BLOCKED)<>0) then
       begin
        s:=SELF_SEGMENT_INDEX(self_segs[i].flags);
        s:=elf_phdr[s].p_offset;
        MinSeg:=MinInt64(s,MinSeg);
        s:=s+minInt64(self_segs[i].filesz,self_segs[i].filesz);
        MaxSeg:=MaxInt64(s,MaxSeg);
       end;

      if (MinSeg>MaxSeg) then
      begin
       FreeMem(self_hdr);
       Exit(EFAULT);
      end;

      imgp^.image_header:=AllocMem(MaxSeg);
      imgp^.elf_size    :=MaxSeg;

      //elf_hdr part
      n:=ptruint(elf_hdr)-ptruint(self_hdr);        //offset to hdr
      s:=self_hdr^.Header_Size+self_hdr^.Meta_size; //offset to end
      s:=MinInt64(obj_size,s);                      //min size
      s:=MaxInt64(s,n)-n;                           //get size

      //first page
      Move(elf_hdr^,imgp^.image_header^,s);

      count:=self_hdr^.Num_Segments;

      For i:=0 to count-1 do
       if ((self_segs[i].flags and SELF_PROPS_BLOCKED)<>0) then
       begin
        s:=SELF_SEGMENT_INDEX(self_segs[i].flags);

        mem_size:=minInt64(self_segs[i].filesz,self_segs[i].memsz);

        src_ofs:=self_segs[i].offset;  //start offset
        dst_ofs:=elf_phdr[s].p_offset; //start offset

        fixup_offset_size(src_ofs,mem_size,obj_size);
        fixup_offset_size(dst_ofs,mem_size,MaxSeg);

        Move( (Pointer(self_hdr)          +src_ofs)^, //src
              (Pointer(imgp^.image_header)+dst_ofs)^, //dst
              mem_size);                              //size
       end;

      imgp^.image_self:=self_hdr;
    end;
  else
    begin
     Exit(ENOEXEC);
    end;
 end;

end;

procedure exec_load_authinfo(imgp:p_image_params);
var
 hdr:p_elf64_hdr;
 authinfo:p_self_authinfo;
 s:ptruint;
begin
 if (imgp=nil) then Exit;

 imgp^.authinfo:=Default(t_authinfo);
 imgp^.authinfo.app_type_id:=QWORD($3100000000000001);

 if (imgp^.image_header=nil) then Exit;
 if (imgp^.image_self  =nil) then Exit;

 hdr:=imgp^.image_header;
 s:=SizeOf(t_self_header);
 s:=s+(imgp^.image_self^.Num_Segments*SizeOf(t_self_segment));
 s:=s+get_elf_phdr_offset(hdr);
 s:=s+(hdr^.e_phnum*SizeOf(elf64_phdr));
 s:=AlignUp(s,SELF_SEGMENT_BLOCK_ALIGNMENT);

 authinfo:=Pointer(Pointer(imgp^.image_self)+s);

 imgp^.authinfo.app_type_id:=authinfo^.AuthorityID;
end;

function is_used_mode_2mb(phdr:p_elf64_phdr;is_dynlib,budget_ptype_caller:Integer):Boolean;
var
 flag_write:Integer;
begin
 Result:=False;

 if (budget_ptype_caller=0) then
 begin
  flag_write:=2;
  if (phdr^.p_type<>PT_SCE_RELRO) then
  begin
   flag_write:=phdr^.p_flags and 2;
  end;

  case g_mode_2mb of
   M2MB_NOTDYN_FIXED:Result:=(is_dynlib=0) and (g_self_fixed<>0);
   M2MB_READONLY    :Result:=(flag_write=0);
   M2MB_ENABLE      :Result:=True;
   else;
  end;

 end;
end;

function rtld_dirname(path,bname:pchar):Integer;
var
 endp:pchar;
begin
 Result:=0;

 { Empty or NULL string gets treated as "." }
 if (path=nil) or (path^=#0) then
 begin
  bname[0]:='.';
  bname[1]:=#0;
  Exit(0);
 end;

 { Strip trailing slashes }
 endp:=path + strlen(path) - 1;
 while (endp > path) and ((endp^='/') or (endp^='\')) do Dec(endp);

 { Find the start of the dir }
 while (endp > path) and ((endp^<>'/') and (endp^<>'\')) do Dec(endp);

 { Either the dir is "/" or there are no slashes }
 if (endp=path) then
 begin
  if ((endp^='/') or (endp^='\')) then
  begin
   bname[0]:='/';
  end else
  begin
   bname[0]:='.';
  end;
  bname[1]:=#0;
  Exit(0);
 end else
 begin
  repeat
   Dec(endp);
  until not ((endp > path) and ((endp^='/') or (endp^='\')));
 end;

 if ((endp - path + 2) > PATH_MAX) then
 begin
  Writeln(StdErr,'Filename is too long:',path);
  Exit(-1);
 end;

 Move(path^, bname^, endp - path + 1);
 bname[endp - path + 1]:=#0;

 Result:=0;
end;

function rtld_file_exists(path:pchar):Boolean;
var
 nd:t_nameidata;
 error:Integer;
begin
 Result:=False;
 if (path=nil) then Exit;

 NDINIT(@nd,LOOKUP,LOCKLEAF or FOLLOW or SAVENAME or MPSAFE, UIO_SYSSPACE, path, curkthread);

 error:=nd_namei(@nd);

 if (error=0) then
 begin
  NDFREE(@nd, NDF_ONLY_PNBUF);
  vput(nd.ni_vp);
  Exit(True);
 end;

 NDFREE(@nd, NDF_ONLY_PNBUF);
end;

end.
