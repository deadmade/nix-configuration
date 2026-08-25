{
  hostname = "10.10.10.137";
  sshUser = "admin";
  user = "root";
  # SD-card-backed Pi doing a release upgrade can exceed deploy-rs's defaults;
  # a timeout here would trigger a spurious rollback mid-activation.
  activationTimeout = 1200;
  confirmTimeout = 120;
  magicRollback = true;
  autoRollback = true;
}
