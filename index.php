<?php
/**
 * Oh, let's be careful with this one. :)
 */

$username = $_GET['username'];
$password = $_GET['password'];
$disallow_robots = (int)$_GET['disallow_robots'];

if (!file_exists('robots.txt')) {
    if ($fh = fopen('robots.txt', 'w')) {
        fwrite($fh, "User-Agent: *\n");
        fclose($fh);
    } else {
        die("Couldn't create robots.txt. Make sure your directory permissions are set appropriately?");
    }
}

$cmd = 'fetlife-export.pl';
$export_dir = $username . @date('-Y-m-d');

?><!DOCTYPE html>
<html lang="en">
<head>
<title>FetLife Exporter</title>
</head>
<body>
    <h1>FetLife Exporter</h1>
    <p>This tool lets you export your FetLife history.</p>
    <form action="<?php print $_SERVER['PHP_SELF']?>">
        <fieldset>
            <legend>FetLife connection details</legend>
            <label for="username">Username:</label>
            <input name="username" id="username" value="username" />
            <label for="password">Password:</label>
            <input type="password" name="password" id="password" value="password" />
        </fieldset>
        <fieldset>
            <legend>Export options</legend>
            <label for="disallow_robots">Ask search engines not to index your exported archive:</label>
            <input type="checkbox" name="disallow_robots" id="disallow_robots" value="1" />
        </fieldset>
        <input type="submit" />
    </form>
<?php

if (empty($username) || empty($password)) {
    die("</body></html><!-- No username or password found. -->");
}

$cmd_safe = escapeshellcmd("./$cmd " . escapeshellarg($username) . ' ' . escapeshellarg($export_dir));

$descriptorspec = array(
    0 => array("pipe", "r"), // stdin is a pipe that the child will read from
    1 => array("pipe", "w"), // stdout is a pipe that the child will write to
    2 => array("pipe", "w")  // stderr is a pipe that the child will write to
);
$pipes = array();
$ph = proc_open($cmd_safe, $descriptorspec, $pipes, './');
if (!is_resource($ph)) {
    die("Error executing $cmd_safe");
}

if ('Password: ' === stream_get_contents($pipes[1], 10)) {
    fwrite($pipes[0], "$password\n");
}

while ($line = stream_get_line($pipes[1], 1024)) {
//    var_dump(str_replace("\n", '\n', str_replace("\r", '\r', $line)));

    if (empty($line)) { continue; }

    // Extract info from output.
    $matches = array();
    if (preg_match('/userID: ([0-9]+)/', $line, $matches)) {
        $id = $matches[1];
    }
    if (preg_match('/([0-9]+) conversations? found./', $line, $matches)) {
        $num_conversations = $matches[1];
    }
    if (preg_match('/([0-9]+) wall-to-walls? found./', $line, $matches)) {
        $num_wall_to_walls = $matches[1];
    }
    if (preg_match('/([0-9]+) status(?:es)? found./', $line, $matches)) {
        $num_statuses = $matches[1];
    }
    if (preg_match('/([0-9]+) pictures? found./', $line, $matches)) {
        $num_pics = $matches[1];
    }
    if (preg_match('/([0-9]+) writings? found./', $line, $matches)) {
        $num_writings = $matches[1];
    }
    if (preg_match('/([0-9]+) group threads? found./', $line, $matches)) {
        $num_group_threads = $matches[1];
    }
}

foreach ($pipes as $pipe) {
    fclose($pipe);
}
proc_close($ph);

if ($disallow_robots && is_dir($export_dir)) {
    if (disallowRobots($export_dir)) {
?>
    <p>We've requested that search engines <em>not</em> index your FetLife export. (This is not a guarantee they'll behave!)</p>
<?php
    } else {
?>
    <p>You requested that search engines <em>not</em> index your FetLife export, but there was an error handling this request. Please contact the site administrator for assistance.</p>
<?php
    }
}
?>
    <p>Done exporting user ID <?php print $id;?>. Found:</p>
    <ul>
        <li><?php printHTMLSafe($num_conversations);?> conversations,</li>
        <li><?php printHTMLSafe($num_wall_to_walls);?> wall-to-walls,</li>
        <li><?php printHTMLSafe($num_statuses);?> statuses,</li>
        <li><?php printHTMLSafe($num_pics);?> pictures,</li>
        <li><?php printHTMLSafe($num_writings);?> writings,</li>
        <li><?php printHTMLSafe($num_group_threads);?> group threads.</li>
    </ul>
    <p><a href="<?php printHTMLSafe($export_dir);?>/fetlife/">Browse <?php printHTMLSafe($username);?></a>.</p>
</body>
</html>
<?
function printHTMLSafe ($str) {
    print htmlentities($str, ENT_QUOTES, 'UTF-8');
}

function disallowRobots ($dir) {
    if (!$fh = fopen('robots.txt', 'a')) {
        return false;
    }
    $ret = fwrite($fh, "Disallow: $dir/\n");
    fclose($fh);
    return $ret;
}
?>