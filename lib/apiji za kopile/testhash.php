<?php
$password = 'milan'; // npr. admin123
$hash = '$6$rounds=5000$ojq9cQ6NZSaeUA$iKTEqVEbtfXQ8bmQTFEaT.jF12d7cqPiLfnT8YEDJYJfSbBRvlT3L2SzWh52Om3QsAdsHQlSY9LcSUT1RiSBx1';

if (hash_equals($hash, crypt($password, $hash))) {
    echo "✅ Lozinka ispravna";
} else {
    echo "❌ Lozinka NIJE ispravna";
}
