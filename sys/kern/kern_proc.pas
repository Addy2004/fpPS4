unit kern_proc;

{$mode ObjFPC}{$H+}
{$CALLING SysV_ABI_CDecl}

interface

uses
 kern_mtx,
 sys_event;

type
 {
  * pargs, used to hold a copy of the command line, if it had a sane length.
  }
 p_pargs=^t_pargs;
 t_pargs=packed record
  ar_ref   :Integer;  // Reference count.
  ar_length:Integer;  // Length.
  ar_args  :AnsiChar; // Arguments.
 end;

const
 MAXCOMLEN=19;

var
 p_proc:record
  p_mtx:mtx;

  p_flag :Integer;
  p_osrel:Integer;

  p_sdk_version:Integer;
  p_sce_replay_exec:Integer;

  libkernel_start_addr:Pointer;
  libkernel___end_addr:Pointer;

  p_ptc:Int64;

  p_nsignals:Int64;
  p_nvcsw   :Int64;
  p_nivcsw  :Int64;

  p_comm           :array[0..MAXCOMLEN] of AnsiChar;
  prog_name        :array[0..1023] of AnsiChar;
  p_randomized_path:array[0..7] of AnsiChar;

  p_klist:t_knlist;

  p_args:p_pargs;

  p_dmem_aliasing:Integer;
 end;

function  pargs_alloc(len:Integer):p_pargs;
procedure pargs_free(pa:p_pargs);
procedure pargs_hold(pa:p_pargs);
procedure pargs_drop(pa:p_pargs);

procedure PROC_LOCK;
procedure PROC_UNLOCK;

procedure PROC_INIT; //SYSINIT

implementation

uses
 kern_event,
 md_time;

//

function pargs_alloc(len:Integer):p_pargs;
begin
 Result:=AllocMem(sizeof(t_pargs) + len);
 Result^.ar_ref   :=1;
 Result^.ar_length:=len;
end;

procedure pargs_free(pa:p_pargs);
begin
 FreeMem(pa);
end;

procedure pargs_hold(pa:p_pargs);
begin
 if (pa=nil) then Exit;
 System.InterlockedIncrement(pa^.ar_ref);
end;

procedure pargs_drop(pa:p_pargs);
begin
 if (pa=nil) then Exit;
 if (System.InterlockedDecrement(pa^.ar_ref)=0) then
 begin
  pargs_free(pa);
 end;
end;

//

procedure PROC_LOCK;
begin
 mtx_lock(p_proc.p_mtx);
end;

procedure PROC_UNLOCK;
begin
 mtx_unlock(p_proc.p_mtx);
end;

procedure PROC_INIT;
const
 osreldate=$000DBBA0;
begin
 FillChar(p_proc,SizeOf(p_proc),0);
 mtx_init(p_proc.p_mtx,'process lock');

 knlist_init_mtx(@p_proc.p_klist,@p_proc.p_mtx);

 p_proc.p_osrel:=osreldate;

 p_proc.p_randomized_path:='system';

 p_proc.p_ptc:=rdtsc;
end;

end.
