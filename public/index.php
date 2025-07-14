<?php

echo "<h1>Laravel Docker Deployment System</h1>";
echo "<p>System is working correctly!</p>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Server: " . $_SERVER['SERVER_SOFTWARE'] . "</p>";

// Test database connection
try {
    $pdo = new PDO('mysql:host=mysql;dbname=laravel', 'laravel', 'secret');
    echo "<p>✅ Database connection: OK</p>";
} catch(PDOException $e) {
    echo "<p>❌ Database connection: " . $e->getMessage() . "</p>";
}

// Test redis connection
try {
    $redis = new Redis();
    $redis->connect('redis', 6379);
    echo "<p>✅ Redis connection: OK</p>";
} catch(Exception $e) {
    echo "<p>❌ Redis connection: " . $e->getMessage() . "</p>";
}

phpinfo();