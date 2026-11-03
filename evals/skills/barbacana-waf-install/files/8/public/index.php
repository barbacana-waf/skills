<?php
// legacy order-entry form (PHP 7.4); accepts file uploads
session_start();
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['attachment'])) {
    move_uploaded_file($_FILES['attachment']['tmp_name'], '/tmp/' . basename($_FILES['attachment']['name']));
}
echo '<form method="post" enctype="multipart/form-data"><input type="file" name="attachment"><input type="submit"></form>';
