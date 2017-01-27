use strict;
use warnings;

use Test::More tests => 13;
use Test::Deep;
use FindBin;

use lib $FindBin::Bin. '/../lib';

use_ok q{Amazon::Dash::Button::Device};

my $adb;

ok !eval { Amazon::Dash::Button::Device->new(); 1 }, 'new fail';
like $@, qr{mac address is undefined};

ok !eval { Amazon::Dash::Button::Device->new( mac => q{00:11:22:33:44:55}); 1 }, 'new fail';

isa_ok $adb, 'Amazon::Dash::Button::Device';


