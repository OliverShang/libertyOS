#include "fs.h"
#include "global.h"
#include "hd.h"
#include "proc.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "sysconst.h"
#include "type.h"

STATIC void clear_inode(struct i_node *pin);

/**
 * close a file.
 *
 * @return (0): if successful, or (-1) if failed
 */
int close(int fd) {
  struct message msg;

  msg.value = FILE_CLOSE;
  msg.FD = fd;

  sendrecv(BOTH, PID_TASK_FS, &msg);

  return msg.RETVAL;
}

int do_close() {
  int fd = fs_msg.FD;
  struct proc *pcaller = proc_table + fs_msg.source;

  if (fd < 0 || fd >= NR_FILES) {
    return -1;
  }

  clear_inode(pcaller->filp[fd]->fd_inode); /* 1.释放 inode_table[] 里相应槽位 */
  pcaller->filp[fd]->fd_inode = NULL;       /* 2.释放指向 inode_table[] 槽位的指针 */
  pcaller->filp[fd] = NULL;                 /* 3.释放指向 f_desc_table[] 槽位的指针 */

  return 0;
}

STATIC void clear_inode(struct i_node *pin) {
  assert(pin);
  assert(pin->i_cnt > 0);
  pin->i_cnt--;
}
