local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";
{
  local assets = self,

  components(observed, specs):: metacontroller.collection(observed, specs, "v1", "ConfigMap", assets.configMap),

  configMap(observed, spec):: {
    local spec = chj.spec(observed, spec),
    local metadata = observed.parent.metadata,

    apiVersion: 'v1',
    kind: 'ConfigMap',

    metadata: {
      name:  chj.assetsName(observed, spec),
      namespace: chj.namespace(observed, spec),
      labels: chj.labels(observed, spec),
    },
    data: {
      'gen_hostfile.sh': |||
        set -xev

        target=$1
        max_try=$2

        trap "rm -f ${target}_new" EXIT TERM INT KILL

        tried=0
        until [ "$(wc -l < ${target}_new)" -eq %(replicas)d ]; do
          pod_names=$(kubectl -n %(namespace)s get pod \
            --selector='%(jobLabelKey)s=%(jobName)s,%(roleLabelKey)s=%(workerLabelValue)s' \
            --field-selector=status.phase=Running \
            -o=jsonpath='{.items[*].metadata.name}')

          rm -f ${target}_new
          for p in ${pod_names}; do
            echo "${p}.%(subdomainName)s" >> ${target}_new
          done

          tried=$(expr $tried + 1)
          if [ -n "$max_try" ] && [ $max_try -ge $tried ]; then
            break
          fi
        done

        if [ -e ${target}_new ]; then
          mv ${target}_new ${target}
        fi
      ||| % {
        namespace: chj.namespace(observed, spec),
        subdomainName: chj.subdomainName(observed, spec),
        jobLabelKey: chj.jobLabelKey(observed, spec),
        jobName: chj.jobName(observed, spec),
        roleLabelKey: chj.roleLabelKey(observed, spec),
        workerLabelValue: chj.workerLabelValue,
        replicas: spec.worker.replicas
      },

      'start_sshd.sh': |||
        #! /bin/sh
        # REQUIREED ARGUMENTS
        # - $1: workdir for sshd. it should be owned by ME and permission of 755
        #       (e.g. $HOME/.chainerjob).
        # - $2: dir ssh key placed. it should be readable by ME

        ME=$(id -u)
        MY_NAME=$(getent passwd "$ME" | cut -d: -f1)

        SSHD_WORK_DIR=$1
        SSH_KEYDIR=$2

        if [ "$ME" = "0" ]; then
          PERMIT_ROOT_LOGIN=yes
        else
          PERMIT_ROOT_LOGIN=no
        fi

        # confirm SSHD_WORK_DIR and SSHD_WORK_DIR/user_keys can be ME:ME 755.
        chmod 755 $SSHD_WORK_DIR
        mkdir -p $SSHD_WORK_DIR/user_keys
        chmod 755 $SSHD_WORK_DIR/user_keys

        # Generating ephemeral hostkeys
        mkdir -p $SSHD_WORK_DIR/host_keys
        ssh-keygen -f $SSHD_WORK_DIR/host_keys/host_rsa_key -C '' -N '' -t rsa
        ssh-keygen -f $SSHD_WORK_DIR/host_keys/host_dsa_key -C '' -N '' -t dsa

        # copy mounted user($SSH_USER) key files to local directory
        # to correct their permissions (600 for files, 700 for directories).
        create_ssh_key() {
          user=$1
          mkdir -p $SSHD_WORK_DIR/user_keys/$user
          chmod 700 $SSHD_WORK_DIR/user_keys/$user
          chown $user:$user $SSHD_WORK_DIR/user_keys/$user
          cp $SSH_KEYDIR/* $SSHD_WORK_DIR/user_keys/$user/
          chmod 600 $SSHD_WORK_DIR/user_keys/$user/*
          chown $user:$user $SSHD_WORK_DIR/user_keys/$user/*
        }

        create_ssh_key $MY_NAME

        # generating sshd_config
        cat << EOT > $SSHD_WORK_DIR/sshd_config
        # Package generated configuration file
        # See the sshd_config(5) manpage for details

        # What ports, IPs and protocols we listen for
        Port 20022
        # Use these options to restrict which interfaces/protocols sshd will bind to
        #ListenAddress ::
        #ListenAddress 0.0.0.0
        Protocol 2

        PidFile $SSHD_WORK_DIR/sshd.pid

        # HostKeys for protocol version 2
        HostKey $SSHD_WORK_DIR/host_keys/host_rsa_key
        HostKey $SSHD_WORK_DIR/host_keys/host_dsa_key

        #Privilege Separation is turned on for security
        UsePrivilegeSeparation no

        # Lifetime and size of ephemeral version 1 server key
        KeyRegenerationInterval 3600
        ServerKeyBits 768

        # Logging
        SyslogFacility AUTH
        LogLevel INFO

        # Authentication:
        LoginGraceTime 120
        PermitRootLogin $PERMIT_ROOT_LOGIN
        StrictModes yes

        RSAAuthentication yes
        PubkeyAuthentication yes
        AuthorizedKeysFile $SSHD_WORK_DIR/user_keys/%u/authorized_keys

        # Don't read the user's ~/.rhosts and ~/.shosts files
        IgnoreRhosts yes
        # For this to work you will also need host keys in /etc/ssh_known_hosts
        RhostsRSAAuthentication no
        # similar for protocol version 2
        HostbasedAuthentication no
        # Uncomment if you don't trust ~/.ssh/known_hosts for RhostsRSAAuthentication
        #IgnoreUserKnownHosts yes

        # To enable empty passwords, change to yes (NOT RECOMMENDED)
        PermitEmptyPasswords no

        # Change to yes to enable challenge-response passwords (beware issues with
        # some PAM modules and threads)
        ChallengeResponseAuthentication no

        X11Forwarding yes
        X11DisplayOffset 10
        PrintMotd no
        PrintLastLog yes
        TCPKeepAlive yes
        #UseLogin no

        # Allow client to pass locale environment variables
        AcceptEnv LANG LC_*
        # AcceptEnv OMPI_MCA_* CHAINERJOB_*
        Subsystem sftp /usr/lib/openssh/sftp-server

        # Set this to 'yes' to enable PAM authentication, account processing,
        # and session processing. If this is enabled, PAM authentication will
        # be allowed through the ChallengeResponseAuthentication and
        # PasswordAuthentication.  Depending on your PAM configuration,
        # PAM authentication via ChallengeResponseAuthentication may bypass
        # the setting of "PermitRootLogin without-password".
        # If you just want the PAM account and session checks to run without
        # PAM authentication, then enable this but set PasswordAuthentication
        # and ChallengeResponseAuthentication to 'no'.
        UsePAM no

        # we need this to set various variables (LD_LIBRARY_PATH etc.) for users
        # since sshd wipes all previously set environment variables when opening
        # a new session
        PermitUserEnvironment yes
        EOT

        cat << EOT > $SSHD_WORK_DIR/ssh_config
        StrictHostKeyChecking no
        IdentityFile $SSHD_WORK_DIR/user_keys/$MY_NAME/id_rsa
        Port 20022
        # SendEnv OMPI_MCA_* CHAINERJOB_*
        UserKnownHostsFile=/dev/null
        EOT

        cat << EOT > $SSHD_WORK_DIR/ssh-wrapper
        #! /bin/sh
        ssh -F $SSHD_WORK_DIR/ssh_config
        EOT
        # to prevent expanding '$@' in the above heredoc
        sed -i 's/ssh_config/ssh_config $@/' $SSHD_WORK_DIR/ssh-wrapper
        chmod +x $SSHD_WORK_DIR/ssh-wrapper

        # dummy supervisor..
        while true
        do
          echo "starting sshd"
          /usr/sbin/sshd -eD -f $SSHD_WORK_DIR/sshd_config
          echo "sshd exited with return code $?"
        done
      |||,

      'init.sh': |||
        #! /bin/sh
        # REQUIRED ENVIRONMENT VARIABLES
        # - $CHAINERJOB_ROLE: master or worker
        # - $CHAINERJOB_SSHD_WORK_DIR: working directory to boot up sshd (its permission should be '755' and owned by me)
        # - $CHAINERJOB_SSH_KEY_DIR: directory where ssh keys placed (it must be readable by me)

        $(cd $(dirname $0);pwd)/start_sshd.sh $HOME/.chainerjob $CHAINERJOB_SSH_KEY_DIR >/tmp/sshd.log 2>&1 &

        # magic sleep for waiting sshd being up
        sleep 5
        echo "sshd started pid=$(ps auwx |grep [s]sh |  awk '{print $2}')"

        if [ $CHAINERJOB_ROLE = "master" ]; then
          export OMPI_MCA_plm_rsh_agent="$HOME/.chainerjob/ssh-wrapper"

          bash -c "$*";
          return_code=$?;
        else
          trap exit TERM;
          sleep infinity & wait
        fi
        echo -n "$return_code" > /dev/termination-log
        exit $return_code
      |||
    }
  },

  status(assets):: {
    local metadata = k8s.getKeyOrElse(assets, 'metadata', {}),
    name: if 'name' in metadata then metadata.name else '',
    apiVersion: if 'apiVersion' in assets then assets.apiVersion else '',
    kind: if 'kind' in assets then assets.kind else '',
  }
}
