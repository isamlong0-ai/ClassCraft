/* =============================================================
 * ClassCraft SMP - Lapisan Data (Supabase + fallback localStorage)
 * -------------------------------------------------------------
 * Semua akses data aplikasi melewati objek global `CC`.
 * Jika Supabase belum dikonfigurasi (assets/supabase-config.js),
 * otomatis memakai localStorage sehingga aplikasi tetap jalan.
 * ============================================================= */
(function () {
    'use strict';

    var cfg = window.CC_CONFIG || {};
    var configured = !!(cfg.SUPABASE_URL && cfg.SUPABASE_ANON_KEY && window.supabase);
    var sb = configured ? window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY) : null;

    // Supabase Auth memakai email. Username/NIP dipetakan ke email internal.
    var EMAIL_DOMAIN = '@classcraft.local';
    function emailFor(username) { return String(username == null ? '' : username).trim().toLowerCase() + EMAIL_DOMAIN; }

    var KEY = {
        users: 'cc_smp_users',
        sekolah: 'cc_smp_sekolah',
        rombel: 'cc_smp_rombel',
        session: 'cc_smp_session'
    };

    var DEFAULT_USERS = [
        { username: 'admin', pass: 'admin123', role: 'admin', nama: 'Administrator Sekolah', mapel: 'Sistem', pangkat: '-', gol: '-' },
        { username: '198001012005011001', pass: 'guru123', role: 'guru', nama: 'Budi Santoso S.Pd', mapel: 'Pendidikan Pancasila', pangkat: 'Pembina', gol: 'IV/a' }
    ];

    var DEFAULT_SEKOLAH = {
        nama: 'SMP Negeri 1 Indonesia', npsn: '10203040',
        kepsek: 'Dr. H. Ahmad Dahlan M.Pd', nipKepsek: '196805121992031002',
        tahunAjaran: '2025/2026', semester: 'Ganjil', imgKop: '', imgTtd: ''
    };

    var DEFAULT_ROMBEL = [
        { id: '7-A', tingkat: 'Kelas 7', nama: '7-A', wali: 'Budi Santoso S.Pd', siswa: [
            { id: 'seed-1', nisn: '0081234561', nipd: '232407001', nama: 'Ahmad Dahlan', jk: 'L' },
            { id: 'seed-2', nisn: '0081234562', nipd: '232407002', nama: 'Siti Walidah', jk: 'P' }
        ] }
    ];

    function uid() {
        if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
        return 'id-' + Date.now() + '-' + Math.floor(Math.random() * 1e6);
    }

    function lsGet(key, fallback) {
        try {
            var raw = localStorage.getItem(key);
            if (raw == null) return fallback;
            return JSON.parse(raw);
        } catch (e) { return fallback; }
    }
    function lsSet(key, value) {
        try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) { /* penuh / diblokir */ }
    }

    // ---------- Sesi (selalu lokal) ----------
    function getSession() { return lsGet(KEY.session, null); }
    function setSession(s) { lsSet(KEY.session, s); }
    function clearSession() { try { localStorage.removeItem(KEY.session); } catch (e) {} }

    // ---------- Sekolah ----------
    // Semester otomatis dari tanggal: 6 bulan awal tahun (Jan-Jun) = Genap,
    // 6 bulan berikutnya (Jul-Des) = Ganjil.
    function semesterSaatIni(d) {
        var bulan = (d ? new Date(d) : new Date()).getMonth() + 1; // 1..12
        return bulan <= 6 ? 'Genap' : 'Ganjil';
    }

    function mapSekolah(row) {
        return {
            nama: row.nama || DEFAULT_SEKOLAH.nama,
            npsn: row.npsn || '',
            kepsek: row.kepsek || '',
            nipKepsek: row.nip_kepsek || '',
            tahunAjaran: row.tahun_ajaran || DEFAULT_SEKOLAH.tahunAjaran,
            semester: semesterSaatIni(),
            imgKop: row.img_kop || '',
            imgTtd: row.img_ttd || ''
        };
    }

    async function getSekolah() {
        if (sb) {
            try {
                var res = await sb.from('sekolah').select('*').limit(1).maybeSingle();
                if (!res.error && res.data) {
                    var mapped = mapSekolah(res.data);
                    lsSet(KEY.sekolah, mapped); // simpan cache untuk mode offline
                    return mapped;
                }
            } catch (e) { console.warn('Gagal memuat sekolah dari Supabase, memakai cache:', e); }
        }
        var cached = lsGet(KEY.sekolah, null) || Object.assign({}, DEFAULT_SEKOLAH);
        cached.semester = semesterSaatIni();
        return cached;
    }

    async function saveSekolah(data) {
        lsSet(KEY.sekolah, data);
        if (sb) {
            var payload = {
                nama: data.nama, npsn: data.npsn, kepsek: data.kepsek,
                nip_kepsek: data.nipKepsek, tahun_ajaran: data.tahunAjaran,
                semester: data.semester, img_kop: data.imgKop, img_ttd: data.imgTtd,
                updated_at: new Date().toISOString()
            };
            var existing = await sb.from('sekolah').select('id').limit(1).maybeSingle();
            if (existing.error) throw existing.error;
            if (existing.data && existing.data.id) {
                var upd = await sb.from('sekolah').update(payload).eq('id', existing.data.id);
                if (upd.error) throw upd.error;
            } else {
                var ins = await sb.from('sekolah').insert(payload);
                if (ins.error) throw ins.error;
            }
        }
    }

    // ---------- Akun guru / admin ----------
    function seedUsersLocal() {
        var users = lsGet(KEY.users, null);
        if (!users) { users = DEFAULT_USERS.slice(); lsSet(KEY.users, users); }
        return users;
    }

    async function getUsers() {
        if (sb) {
            try {
                var res = await sb.from('guru').select('id,username,role,nama,mapel,pangkat,gol').order('role').order('nama');
                if (res.error) throw res.error;
                return res.data || [];
            } catch (e) {
                console.warn('Gagal memuat guru dari Supabase, memakai data lokal:', e);
            }
        }
        return seedUsersLocal();
    }

    async function addUser(u) {
        var payload = {
            username: u.username, pass: u.pass || 'guru123', role: u.role || 'guru',
            nama: u.nama, mapel: u.mapel || '', pangkat: u.pangkat || '-', gol: u.gol || '-'
        };
        if (sb) {
            var res = await sb.rpc('admin_create_guru', {
                p_username: payload.username, p_password: payload.pass, p_role: payload.role,
                p_nama: payload.nama, p_mapel: payload.mapel, p_pangkat: payload.pangkat, p_gol: payload.gol
            });
            if (res.error) throw res.error;
            return (res.data && res.data[0]) || payload;
        }
        var users = seedUsersLocal();
        users.push(payload);
        lsSet(KEY.users, users);
        return payload;
    }

    async function resetPassword(username, newPass) {
        newPass = newPass || 'guru123';
        if (sb) {
            var res = await sb.rpc('admin_reset_guru_password', { p_username: username, p_password: newPass });
            if (res.error) throw res.error;
            return;
        }
        var users = seedUsersLocal();
        var idx = users.findIndex(function (x) { return x.username === username; });
        if (idx !== -1) { users[idx].pass = newPass; lsSet(KEY.users, users); }
    }

    // Hapus guru + akun Auth-nya (khusus admin). Menolak admin, akun sendiri,
    // dan guru yang punya catatan presensi (dilakukan oleh RPC di server).
    async function deleteUser(username) {
        if (sb) {
            var res = await sb.rpc('admin_delete_guru', { p_username: username });
            if (res.error) throw res.error;
            return;
        }
        var users = seedUsersLocal().filter(function (x) { return x.username !== username; });
        lsSet(KEY.users, users);
    }

    // Profil guru milik user yang sedang login (dipakai ulang beberapa fungsi).
    async function fetchProfile(authUserId) {
        var prof = await sb.from('guru')
            .select('id,username,role,nama,mapel,pangkat,gol')
            .eq('id', authUserId).maybeSingle();
        if (prof.error) throw prof.error;
        return prof.data || null;
    }

    // Ubah error Supabase Auth menjadi pesan yang mudah dipahami pengguna.
    function authErrorMessage(err) {
        if (!err) return '';
        var code = err.code || err.error_code || '';
        var msg = err.message || String(err);
        if (code === 'invalid_credentials' || /invalid login credentials/i.test(msg)) {
            return 'NIP/Username atau Password salah. Pastikan NIP sesuai dan password awal guru adalah "guru123".';
        }
        if (code === 'email_not_confirmed' || /email not confirmed/i.test(msg)) {
            return 'Akun belum dikonfirmasi. Hubungi admin sekolah.';
        }
        if (code === 'over_request_rate_limit' || /rate limit|too many/i.test(msg)) {
            return 'Terlalu banyak percobaan masuk. Tunggu sebentar lalu coba lagi.';
        }
        if (/failed to fetch|networkerror|load failed/i.test(msg)) {
            return 'Tidak dapat menghubungi server. Periksa koneksi internet Anda.';
        }
        return msg;
    }

    // Versi login yang mengembalikan pesan error asli (untuk ditampilkan di form).
    async function loginDetailed(username, password) {
        username = String(username == null ? '' : username).trim();
        if (sb) {
            var res = await sb.auth.signInWithPassword({ email: emailFor(username), password: password });
            if (res.error) return { user: null, error: authErrorMessage(res.error), code: res.error.code || '' };
            if (!res.data || !res.data.user) {
                return { user: null, error: 'NIP/Username atau Password salah.', code: 'invalid_credentials' };
            }
            try {
                var prof = await fetchProfile(res.data.user.id);
                if (!prof) {
                    await sb.auth.signOut();
                    return { user: null, error: 'Akun terautentikasi, tetapi profil guru tidak ditemukan. Hubungi admin sekolah.', code: 'profile_missing' };
                }
                return { user: prof, error: null, code: '' };
            } catch (e) {
                await sb.auth.signOut();
                return { user: null, error: authErrorMessage(e), code: (e && e.code) || 'profile_error' };
            }
        }
        var users = seedUsersLocal();
        var u = users.find(function (x) { return String(x.username).trim() === username && x.pass === password; });
        return u ? { user: Object.assign({}, u), error: null, code: '' } : { user: null, error: 'NIP/Username atau Password salah.', code: 'invalid_credentials' };
    }

    async function login(username, password) {
        var r = await loginDetailed(username, password);
        return r.user;
    }

    async function logout() {
        clearSession();
        if (sb) { try { await sb.auth.signOut(); } catch (e) { /* abaikan */ } }
    }

    // Ambil user yang benar-benar terautentikasi (validasi sesi Supabase).
    async function getAuthUser() {
        if (!sb) return getSession();
        try {
            var res = await sb.auth.getSession();
            if (!res.data || !res.data.session) { clearSession(); return null; }
            var prof = await fetchProfile(res.data.session.user.id);
            if (prof) setSession(prof);
            return prof;
        } catch (e) {
            console.warn('Gagal memverifikasi sesi:', e);
            return null;
        }
    }

    // Guard untuk halaman: pastikan login dan (opsional) peran sesuai.
    async function requireAuth(role) {
        var u = await getAuthUser();
        if (!u) return null;
        if (role && u.role !== role) return null;
        return u;
    }

    async function changePassword(username, oldPass, newPass) {
        if (sb) {
            // Verifikasi password lama dengan login ulang, lalu perbarui.
            var check = await sb.auth.signInWithPassword({ email: emailFor(username), password: oldPass });
            if (check.error) return false;
            var upd = await sb.auth.updateUser({ password: newPass });
            if (upd.error) throw upd.error;
            return true;
        }
        var users = seedUsersLocal();
        var idx = users.findIndex(function (x) { return x.username === username; });
        if (idx === -1 || users[idx].pass !== oldPass) return false;
        users[idx].pass = newPass;
        lsSet(KEY.users, users);
        return true;
    }

    // ---------- Rombel & siswa ----------
    function normalizeSiswa(s) {
        return {
            id: s.id || uid(),
            nisn: s.nisn, nipd: s.nipd || '-', nama: s.nama,
            jk: (s.jk || 'L').toUpperCase() === 'P' ? 'P' : 'L',
            status: s.status || 'aktif',
            tanggal_keluar: s.tanggal_keluar || null,
            keterangan: s.keterangan || ''
        };
    }

    async function getRombel() {
        if (sb) {
            try {
                // Roster dibaca dari tabel riwayat penempatan `anggota_rombel`,
                // bukan lagi kolom tunggal siswa.rombel_id.
                var res = await sb.from('rombel')
                    .select('id,tingkat,nama,wali_id,tahun_ajaran,anggota_rombel(siswa(id,nisn,nipd,nama,jk,status,tanggal_keluar,keterangan))')
                    .order('tahun_ajaran')
                    .order('nama');
                if (res.error) throw res.error;
                var guruRes = await sb.from('guru').select('id,nama');
                var map = {};
                (guruRes.data || []).forEach(function (g) { map[g.id] = g.nama; });
                var mapped = (res.data || []).map(function (r) {
                    return {
                        id: r.id, tingkat: r.tingkat, nama: r.nama,
                        tahun_ajaran: r.tahun_ajaran || '',
                        wali: r.wali_id ? (map[r.wali_id] || '-') : '-',
                        siswa: (r.anggota_rombel || [])
                            .map(function (a) { return a.siswa; })
                            .filter(Boolean)
                            .map(normalizeSiswa)
                    };
                });
                lsSet(KEY.rombel, mapped); // simpan cache untuk mode offline
                return mapped;
            } catch (e) {
                console.warn('Gagal memuat rombel dari Supabase, memakai cache:', e);
            }
        }
        var rombel = lsGet(KEY.rombel, null) || DEFAULT_ROMBEL.slice();
        rombel.forEach(function (r) { r.siswa = (r.siswa || []).map(normalizeSiswa); });
        return rombel;
    }

    async function addRombel(data) {
        if (sb) {
            var waliId = null;
            if (data.wali && data.wali !== '-') {
                var g = await sb.from('guru').select('id').eq('nama', data.wali).maybeSingle();
                if (!g.error && g.data) waliId = g.data.id;
            }
            var ta = data.tahun_ajaran;
            if (!ta) {
                var sek = await getSekolah();
                ta = (sek && sek.tahunAjaran) || '2025/2026';
            }
            var res = await sb.from('rombel')
                .insert({ tingkat: data.tingkat, nama: data.nama, wali_id: waliId, tahun_ajaran: ta })
                .select().single();
            if (res.error) throw res.error;
            return { id: res.data.id, tingkat: res.data.tingkat, nama: res.data.nama, tahun_ajaran: res.data.tahun_ajaran, wali: data.wali || '-', siswa: [] };
        }
        var rombel = await getRombel();
        var sekOff = await getSekolah();
        rombel.push({ id: data.nama, tingkat: data.tingkat, nama: data.nama, tahun_ajaran: data.tahun_ajaran || (sekOff && sekOff.tahunAjaran) || '2025/2026', wali: data.wali || '-', siswa: [] });
        lsSet(KEY.rombel, rombel);
        return rombel[rombel.length - 1];
    }

    async function addSiswa(rombelId, siswa) {
        var row = normalizeSiswa(siswa);
        if (sb) {
            var rb = await sb.from('rombel').select('tahun_ajaran').eq('id', rombelId).single();
            if (rb.error) throw rb.error;
            var ins = await sb.from('siswa')
                .insert({ nisn: row.nisn, nipd: row.nipd, nama: row.nama, jk: row.jk })
                .select().single();
            if (ins.error) throw ins.error;
            var enr = await sb.from('anggota_rombel').insert({
                siswa_id: ins.data.id, rombel_id: rombelId, tahun_ajaran: rb.data.tahun_ajaran
            });
            if (enr.error) {
                // batalkan agar tidak ada siswa tanpa penempatan
                await sb.from('siswa').delete().eq('id', ins.data.id);
                throw enr.error;
            }
            return normalizeSiswa(ins.data);
        }
        var rombel = lsGet(KEY.rombel, null) || DEFAULT_ROMBEL.slice();
        var target = rombel.find(function (r) { return r.id === rombelId; });
        if (!target) throw new Error('Rombel tidak ditemukan');
        target.siswa = (target.siswa || []).map(normalizeSiswa);
        target.siswa.push(row);
        lsSet(KEY.rombel, rombel);
        return row;
    }

    async function importSiswa(rombelId, rows) {
        if (rows.length === 0) return 0;
        if (sb) {
            var rb = await sb.from('rombel').select('tahun_ajaran').eq('id', rombelId).single();
            if (rb.error) throw rb.error;
            var payload = rows.map(function (r) {
                var s = normalizeSiswa(r);
                return { nisn: s.nisn, nipd: s.nipd, nama: s.nama, jk: s.jk };
            });
            var res = await sb.from('siswa').insert(payload).select();
            if (res.error) throw res.error;
            var inserted = res.data || [];
            if (inserted.length === 0) return 0;
            var enr = await sb.from('anggota_rombel').insert(inserted.map(function (s) {
                return { siswa_id: s.id, rombel_id: rombelId, tahun_ajaran: rb.data.tahun_ajaran };
            }));
            if (enr.error) {
                await sb.from('siswa').delete().in('id', inserted.map(function (s) { return s.id; }));
                throw enr.error;
            }
            return inserted.length;
        }
        var rombel = lsGet(KEY.rombel, null) || DEFAULT_ROMBEL.slice();
        var target = rombel.find(function (r) { return r.id === rombelId; });
        if (!target) throw new Error('Rombel tidak ditemukan');
        target.siswa = (target.siswa || []).map(normalizeSiswa);
        rows.forEach(function (r) { target.siswa.push(normalizeSiswa(r)); });
        lsSet(KEY.rombel, rombel);
        return rows.length;
    }

    // Riwayat penempatan kelas seorang siswa (semua tahun ajaran).
    async function getRiwayatSiswa(siswaId) {
        if (!sb) return [];
        var res = await sb.from('anggota_rombel')
            .select('tahun_ajaran,tanggal_masuk,tanggal_keluar,keterangan,rombel(id,nama,tingkat)')
            .eq('siswa_id', siswaId)
            .order('tahun_ajaran');
        if (res.error) throw res.error;
        return (res.data || []).map(function (a) {
            return {
                tahun_ajaran: a.tahun_ajaran,
                rombel: a.rombel ? a.rombel.nama : '-',
                tingkat: a.rombel ? a.rombel.tingkat : '-',
                tanggal_masuk: a.tanggal_masuk,
                tanggal_keluar: a.tanggal_keluar,
                keterangan: a.keterangan || ''
            };
        });
    }

    // Ubah status siswa (aktif/lulus/pindah/berhenti) tanpa menghapus data.
    async function setStatusSiswa(siswaId, status, opts) {
        opts = opts || {};
        var patch = {
            status: status,
            tanggal_keluar: (status === 'aktif') ? null : (opts.tanggalKeluar || new Date().toISOString().slice(0, 10)),
            keterangan: opts.keterangan || ''
        };
        if (sb) {
            var res = await sb.from('siswa').update(patch).eq('id', siswaId);
            if (res.error) throw res.error;
            return patch;
        }
        var rombel = lsGet(KEY.rombel, null) || DEFAULT_ROMBEL.slice();
        rombel.forEach(function (r) {
            (r.siswa || []).forEach(function (s) { if (s.id === siswaId) Object.assign(s, patch); });
        });
        lsSet(KEY.rombel, rombel);
        return patch;
    }

    async function deleteSiswa(siswaId) {
        if (sb) {
            // Tolak hapus permanen bila siswa punya riwayat presensi agar
            // data tidak hilang — gunakan status Pindah/Berhenti.
            var cek = await sb.from('presensi').select('id', { count: 'exact', head: true }).eq('siswa_id', siswaId);
            if (!cek.error && (cek.count || 0) > 0) {
                throw new Error('Siswa memiliki riwayat presensi. Tandai sebagai Pindah/Berhenti, jangan hapus permanen.');
            }
            // hapus penempatan lebih dulu (FK anggota_rombel on delete restrict)
            var delEnr = await sb.from('anggota_rombel').delete().eq('siswa_id', siswaId);
            if (delEnr.error) throw delEnr.error;
            var res = await sb.from('siswa').delete().eq('id', siswaId);
            if (res.error) throw res.error;
            return;
        }
        var rombel = lsGet(KEY.rombel, null) || DEFAULT_ROMBEL.slice();
        rombel.forEach(function (r) {
            r.siswa = (r.siswa || []).filter(function (s) { return (s.id || '') !== siswaId; });
        });
        lsSet(KEY.rombel, rombel);
    }

    // Tahun ajaran berikutnya: '2025/2026' -> '2026/2027'.
    function tahunAjaranBerikutnya(ta) {
        var m = String(ta || '').match(/^(\d{4})\s*\/\s*(\d{4})$/);
        if (!m) return '';
        return (parseInt(m[1], 10) + 1) + '/' + (parseInt(m[2], 10) + 1);
    }

    // Proses kenaikan kelas massal (khusus admin).
    //   dariTa / keTa : tahun ajaran asal & tujuan.
    //   pengecualian  : { siswaId: 'naik'|'tinggal'|'lulus'|'pindah'|'berhenti' }.
    //   aktifkan      : set sekolah.tahun_ajaran = keTa (default true).
    // Mengembalikan ringkasan { naik, tinggal, lulus, pindah, berhenti }.
    async function naikKelas(dariTa, keTa, pengecualian, aktifkan) {
        if (sb) {
            var res = await sb.rpc('admin_naik_kelas', {
                p_dari_ta: dariTa, p_ke_ta: keTa,
                p_pengecualian: pengecualian || {},
                p_aktifkan: aktifkan !== false
            });
            if (res.error) throw res.error;
            return res.data;
        }
        var rombel = await getRombel();
        var sumber = rombel.filter(function (r) { return r.tahun_ajaran === dariTa; });
        var ringkas = { naik: 0, tinggal: 0, lulus: 0, pindah: 0, berhenti: 0 };
        var today = new Date().toISOString().slice(0, 10);
        sumber.forEach(function (r) {
            (r.siswa || []).forEach(function (s) {
                if (s.status && s.status !== 'aktif') return;
                var aksi = (pengecualian && pengecualian[s.id]) || (r.tingkat === 'Kelas 9' ? 'lulus' : 'naik');
                if (aksi === 'lulus' || aksi === 'pindah' || aksi === 'berhenti') {
                    ringkas[aksi]++; s.status = aksi; s.tanggal_keluar = today; return;
                }
                var namaBaru = r.nama, tingkatBaru = r.tingkat;
                if (aksi !== 'tinggal') {
                    var m = String(r.nama).match(/^(\d+)(.*)$/);
                    if (m) {
                        namaBaru = (parseInt(m[1], 10) + 1) + m[2];
                        tingkatBaru = 'Kelas ' + (parseInt(m[1], 10) + 1);
                    }
                    ringkas.naik++;
                } else { ringkas.tinggal++; }
                var tgt = rombel.find(function (x) { return x.nama === namaBaru && x.tahun_ajaran === keTa; });
                if (!tgt) {
                    tgt = { id: namaBaru + '-' + keTa, nama: namaBaru, tingkat: tingkatBaru, tahun_ajaran: keTa, wali: '-', siswa: [] };
                    rombel.push(tgt);
                }
                tgt.siswa.push(Object.assign({}, s));
            });
        });
        lsSet(KEY.rombel, rombel);
        if (aktifkan !== false) {
            var sek = await getSekolah();
            sek.tahunAjaran = keTa; sek.semester = semesterSaatIni();
            await saveSekolah(sek);
        }
        return ringkas;
    }

    // ---------- Backup / Restore ----------
    async function exportAll() {
        var users = await getUsers();
        var sekolah = await getSekolah();
        var rombel = await getRombel();
        return { users: users, sekolah: sekolah, rombel: rombel, exportedAt: new Date().toISOString() };
    }

    async function restoreAll(data) {
        if (!data) return;
        if (data.sekolah) { await saveSekolah(data.sekolah); }
        if (Array.isArray(data.users)) {
            if (!sb) { lsSet(KEY.users, data.users); }
            else {
                for (var i = 0; i < data.users.length; i++) {
                    var u = data.users[i];
                    var existing = await sb.from('guru').select('id').eq('username', u.username).maybeSingle();
                    if (!existing.error && !existing.data) {
                        await addUser(u);
                    }
                }
            }
        }
        if (Array.isArray(data.rombel) && !sb) {
            lsSet(KEY.rombel, data.rombel);
        }
    }

    // Revalidasi sesi terpusat: jika token Supabase tidak valid, paksa ke login.
    if (sb) {
        (function () {
            var path = (window.location.pathname || '').toLowerCase();
            // Lewati revalidasi di halaman login (index.html / login.html / root).
            var isLoginPage = path.indexOf('index.html') !== -1 || path.indexOf('login') !== -1 ||
                              path === '' || path === '/' || /\/$/.test(path);
            if (isLoginPage) return;
            getAuthUser().then(function (u) {
                if (!u) window.location.replace('index.html');
            });
        })();
    }

    window.CC = {
        isConfigured: function () { return configured; },
        client: sb,
        homeFor: function (role) { return role === 'admin' ? 'admin-profil.html' : 'guru-dashboard.html'; },
        getSession: getSession,
        setSession: setSession,
        clearSession: clearSession,
        login: login,
        loginDetailed: loginDetailed,
        logout: logout,
        getAuthUser: getAuthUser,
        requireAuth: requireAuth,
        changePassword: changePassword,
        resetPassword: resetPassword,
        deleteUser: deleteUser,
        getSekolah: getSekolah,
        saveSekolah: saveSekolah,
        getUsers: getUsers,
        addUser: addUser,
        getRombel: getRombel,
        addRombel: addRombel,
        addSiswa: addSiswa,
        importSiswa: importSiswa,
        deleteSiswa: deleteSiswa,
        setStatusSiswa: setStatusSiswa,
        getRiwayatSiswa: getRiwayatSiswa,
        naikKelas: naikKelas,
        tahunAjaranBerikutnya: tahunAjaranBerikutnya,
        semesterSaatIni: semesterSaatIni,
        exportAll: exportAll,
        restoreAll: restoreAll,
        defaults: { users: DEFAULT_USERS, sekolah: DEFAULT_SEKOLAH, rombel: DEFAULT_ROMBEL }
    };
})();
