# ដាក់ PS168 ឱ្យប្រើពិត (Deploy)

ឯកសារនេះពន្យល់ពីរបៀបដាក់ API (Laravel) លើ server ពិត និងរបៀប build App សម្រាប់អតិថិជន។
ឧទាហរណ៍ខាងក្រោមប្រើ **Ubuntu 24.04 VPS** ដែលមាន nginx, PHP 8.3 និង MySQL។

> **Bakong KHQR:** ធនាគារជាតិអាចអនុញ្ញាតឱ្យប្រើ API បានតែពី IP នៅកម្ពុជាប៉ុណ្ណោះ។
> បើចង់ប្រើការផ្ទៀងផ្ទាត់ Bakong ដោយស្វ័យប្រវត្តិ សូមជ្រើស VPS ដែលមាន data center នៅភ្នំពេញ
> ឬសាកសួរ NBC ជាមុនសិន។

---

## ១. ត្រៀម server

```bash
sudo apt update && sudo apt install -y nginx mysql-server git unzip \
  php8.3-fpm php8.3-cli php8.3-mysql php8.3-sqlite3 php8.3-mbstring php8.3-xml \
  php8.3-curl php8.3-zip php8.3-gd php8.3-bcmath php8.3-intl
curl -sS https://getcomposer.org/installer | php && sudo mv composer.phar /usr/local/bin/composer
```

បង្កើត database:

```bash
sudo mysql -e "CREATE DATABASE phoneshop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'phoneshop'@'localhost' IDENTIFIED BY 'ពាក្យសម្ងាត់ខ្លាំង';
GRANT ALL ON phoneshop.* TO 'phoneshop'@'localhost';"
```

## ២. ដាក់កូដ API

```bash
sudo mkdir -p /var/www && cd /var/www
sudo git clone https://github.com/chetsothea/Midterm-aaa.git ps168
cd ps168/phoneshop_api
composer install --no-dev --optimize-autoloader
cp .env.production.example .env
nano .env                       # បំពេញ APP_URL, DB_PASSWORD, MAIL_*, BAKONG_* ...
php artisan key:generate
php artisan migrate --force
sudo chown -R www-data:www-data storage bootstrap/cache public/uploads
```

**គណនី Admin ដំបូង:**

`php artisan db:seed --force` បង្កើតគណនី Admin (Login: `admin` / `admin123`) ព្រមទាំងទូរស័ព្ទគំរូ។

ក្រោយ seed រួច ត្រូវប្តូរពាក្យសម្ងាត់ admin **ភ្លាមៗ**:

```bash
php artisan tinker --execute="App\Models\User::where('role','admin')->first()->forceFill(['password'=>'ពាក្យសម្ងាត់ថ្មី'])->save();"
```

បន្ទាប់មក រក្សាទុក config ឱ្យលឿន ហើយពិនិត្យថាគ្រប់យ៉ាងត្រឹមត្រូវ:

```bash
php artisan config:cache && php artisan route:cache
php artisan shop:check-production
```

`shop:check-production` បង្ហាញ ✗ សម្រាប់ចំណុចដែលមិនមានសុវត្ថិភាព (ត្រូវកែ) និង ! សម្រាប់ចំណុចដែលគួរពិចារណា។

## ៣. nginx និង HTTPS

បង្កើតឯកសារ `/etc/nginx/sites-available/ps168`:

```nginx
server {
    server_name api.your-domain.com;
    root /var/www/ps168/phoneshop_api/public;
    index index.php;
    client_max_body_size 20M;          # រូបទូរស័ព្ទ និងរូប Trade-in

    location / { try_files $uri $uri/ /index.php?$query_string; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
    location ~ /\.(?!well-known) { deny all; }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/ps168 /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.your-domain.com     # HTTPS ឥតគិតថ្លៃ ហើយបន្តដោយខ្លួនឯង
```

## ៤. Scheduler (សំខាន់!)

Scheduler ត្រូវដំណើរការរៀងរាល់នាទី។ បើគ្មានវាទេ App នឹងមិនធ្វើការងារទាំងនេះទេ:
- បោះបង់ Order KHQR ដែលមិនបង់ក្នុង 30 នាទី ហើយដាក់ស្តុកត្រឡប់វិញ
- ពិនិត្យការបង់ប្រាក់ Bakong
- Backup ប្រចាំយប់

```bash
sudo crontab -u www-data -e
# បន្ថែមបន្ទាត់នេះ:
* * * * * cd /var/www/ps168/phoneshop_api && php artisan schedule:run >> /dev/null 2>&1
```

## ៥. Backup

- App backup ដោយខ្លួនឯងរៀងរាល់យប់ ម៉ោង 2:00 (ម៉ោងកម្ពុជា)។ វារក្សាទុក database និងរូបភាពទាំងអស់ នៅក្នុង `storage/app/backups` រយៈពេល 14 ថ្ងៃ។
- Backup ដោយដៃ:

  ```bash
  php artisan shop:backup
  ```

- ⚠️ ក្នុង server ដដែល backup មិនគ្រប់គ្រាន់ទេ។ ចម្លងថត `storage/app/backups` ទៅកន្លែងផ្សេងជាប្រចាំ ឧ. Google Drive ដោយប្រើ `rclone` ឬម៉ាស៊ីនមួយទៀត។
- MySQL backup ត្រូវការ `mysqldump`។ វាមានរួចស្រាប់ពេលដំឡើង `mysql-server`។

## ៦. Update កំណែថ្មី

```bash
cd /var/www/ps168 && sudo -u www-data git pull
cd phoneshop_api && composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize:clear && php artisan config:cache && php artisan route:cache
php artisan shop:backup        # backup ភ្លាមៗក្រោយ update
```

## ៧. Build App សម្រាប់អតិថិជន

ប្តូរ `https://api.your-domain.com` ទៅជាអាសយដ្ឋាន API ពិតរបស់អ្នក។

**Web:**

```bash
cd phoneshop_ms
flutter build web --release --dart-define=API_HOST=https://api.your-domain.com
```

ឯកសារនៅក្នុង `build/web/` ត្រូវដាក់លើ hosting ណាមួយ (nginx, Netlify, Cloudflare Pages ...)។ បន្ទាប់មក ដាក់អាសយដ្ឋាននោះក្នុង `CORS_ALLOWED_ORIGINS`។

**Android (Play Store):**

```bash
flutter build appbundle --release --dart-define=API_HOST=https://api.your-domain.com
```

App release មិនអនុញ្ញាត `http` ទេ មានតែ `https` ប៉ុណ្ណោះ។ `http` ប្រើបានតែក្នុង debug ពេលសាកលើ Wi-Fi។

**iPhone (App Store):** ត្រូវការ Xcode និងគណនី Apple Developer:

```bash
flutter build ipa --release --dart-define=API_HOST=https://api.your-domain.com
```

## ៨. Checklist មុនបើកហាង

- [ ] `php artisan shop:check-production` គ្មាន ✗
- [ ] ប្តូរពាក្យសម្ងាត់ admin ពី `admin123` រួចហើយ (`shop:check-production` ពិនិត្យរឿងនេះដែរ)
- [ ] សាក "ភ្លេចពាក្យសម្ងាត់" ហើយ Email មកដល់ពិតប្រាកដ
- [ ] សាកបញ្ជាទិញ KHQR $0.01 ហើយ Order ប្តូរជា paid ដោយខ្លួនឯង
- [ ] Scheduler ដំណើរការ: ឯកសារ backup ថ្មីលេចឡើងនៅព្រឹកស្អែក
- [ ] ដាក់ QR ABA/ACLEDA និងថ្លៃដឹកនៅក្នុង Admin › 🏪
- [ ] បង្កើតគណនី Staff ឱ្យបុគ្គលិក (កុំឱ្យគេប្រើគណនី Admin)
