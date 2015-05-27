require 'spec_helper_acceptance'

describe 'basic cinder' do

  context 'default parameters' do

    it 'should work with no errors' do
      pp= <<-EOS
      Exec { logoutput => 'on_failure' }

      # Common resources
      include ::apt
      class { '::openstack_extras::repo::debian::ubuntu':
        release         => 'kilo',
        package_require => true,
      }

      class { '::mysql::server': }

      class { '::rabbitmq':
        delete_guest_user => true,
        erlang_cookie     => 'secrete',
      }

      rabbitmq_vhost { '/':
        provider => 'rabbitmqctl',
        require  => Class['rabbitmq'],
      }

      rabbitmq_user { 'cinder':
        admin    => true,
        password => 'an_even_bigger_secret',
        provider => 'rabbitmqctl',
        require  => Class['rabbitmq'],
      }

      rabbitmq_user_permissions { 'cinder@/':
        configure_permission => '.*',
        write_permission     => '.*',
        read_permission      => '.*',
        provider             => 'rabbitmqctl',
        require              => Class['rabbitmq'],
      }

      # Keystone resources, needed by Cinder to run
      class { '::keystone::db::mysql':
        password => 'keystone',
      }
      class { '::keystone':
        verbose             => true,
        debug               => true,
        database_connection => 'mysql://keystone:keystone@127.0.0.1/keystone',
        admin_token         => 'admin_token',
        enabled             => true,
      }
      class { '::keystone::roles::admin':
        email    => 'test@example.tld',
        password => 'a_big_secret',
      }
      class { '::keystone::endpoint':
        public_url => "https://${::fqdn}:5000/",
        admin_url  => "https://${::fqdn}:35357/",
      }

      # Cinder resources
      class { '::cinder':
        database_connection => 'mysql://cinder:a_big_secret@127.0.0.1/cinder?charset=utf8',
        rabbit_userid       => 'cinder',
        rabbit_password     => 'an_even_bigger_secret',
        rabbit_host         => '127.0.0.1',
      }
      class { '::cinder::keystone::auth':
        password => 'a_big_secret',
      }
      class { '::cinder::db::mysql':
        password => 'a_big_secret',
      }
      class { '::cinder::api':
        keystone_password   => 'a_big_secret',
        identity_uri        => 'http://127.0.0.1:35357/',
        default_volume_type => 'iscsi_backend',
      }
      class { '::cinder::backup': }
      class { '::cinder::ceilometer': }
      class { '::cinder::client': }
      class { '::cinder::quota': }
      class { '::cinder::scheduler': }
      class { '::cinder::volume': }
      # TODO: create a backend and spawn a volume
      EOS


      # Run it twice to test for idempotency
      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes => true)
    end

    describe port(8776) do
      it { is_expected.to be_listening.with('tcp') }
    end

  end
end