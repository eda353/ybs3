using System;
using System.Data;
using System.Data.SqlClient;
using System.Windows.Forms;

namespace PerformansYonetimiApp
{
    // ============================================================================
    // 1. EKRAN KATMANI (AnaForm): İş mantığı sınıfına doğrudan bağımlıdır (Sıkı Bağ)
    // ============================================================================
    public partial class AnaForm : Form
    {
        private int aktifYoneticiID = 2; // Mock Yönetici ID
        private int secilenDegerlendirmeID = 0;
        private string baglantiCumlesi = "Server=localhost;Database=PerformansYonetimiDB;Trusted_Connection=True;";

        private DataGridView dgvPerformansListesi;
        private TextBox txtYetkinlikPuani;
        private TextBox txtYoneticiYorumu;
        private Button btnOnaylaVeGonder;
        private Label lblDurumBilgisi;

        public AnaForm()
        {
            ArayuzElemanlariniOlustur(); 
        }

        private void AnaForm_Load(object sender, EventArgs e)
        {
            BekleyenDegerlendirmeleriGetir();
        }

        // Tightly Coupled Kanıtı: Ekran katmanı, hiçbir koruyucu olmadan doğrudan SQL sorgusu çalıştırır.
        private void BekleyenDegerlendirmeleriGetir()
        {
            using (SqlConnection conn = new SqlConnection(baglantiCumlesi))
            {
                string sqlSorgusu = @"
                    SELECT DegerlendirmeID, CalisanID, DonemID, DegerlendirmeDurumu 
                    FROM PerformansDegerlendirme 
                    WHERE YoneticiID = @YoneticiID AND DegerlendirmeDurumu IN ('Taslak', 'Revizyon')";

                SqlCommand cmd = new SqlCommand(sqlSorgusu, conn);
                cmd.Parameters.AddWithValue("@YoneticiID", aktifYoneticiID);

                SqlDataAdapter da = new SqlDataAdapter(cmd);
                DataTable dt = new DataTable();
                da.Fill(dt);
                dgvPerformansListesi.DataSource = dt;
            }
        }

        private void dgvPerformansListesi_CellClick(object sender, DataGridViewCellEventArgs e)
        {
            if (e.RowIndex >= 0)
            {
                secilenDegerlendirmeID = Convert.ToInt32(dgvPerformansListesi.Rows[e.RowIndex].Cells["DegerlendirmeID"].Value);
                lblDurumBilgisi.Text = "Seçilen Değerlendirme ID: " + secilenDegerlendirmeID;
            }
        }

        // Tightly Coupled Kanıtı: Form, alt taraftaki iş sınıfını interface kullanmadan doğrudan "new"ler.
        private void btnOnaylaVeGonder_Click(object sender, EventArgs e)
        {
            if (secilenDegerlendirmeID == 0)
            {
                MessageBox.Show("Lütfen listeden bir kayıt seçin!", "Hata");
                return;
            }

            try
            {
                // Doğrudan somut sınıfa bağımlılık (Sıkı Bağ)
                PerformansIslemleri islem = new PerformansIslemleri();

                decimal yetkinlikPuani = Convert.ToDecimal(txtYetkinlikPuani.Text);
                string yorum = txtYoneticiYorumu.Text;

                // İşlemi başlat ve doğrudan veri tabanına gönder
                islem.DegerlendirmeyiOnaylaVeGonder(secilenDegerlendirmeID, yetkinlikPuani, yorum);

                MessageBox.Show("İşlem Başarılı! SQL'deki sp_NihaiPuanHesapla çalıştırıldı.", "YBS Modülü");
                BekleyenDegerlendirmeleriGetir(); 
            }
            catch (Exception ex)
            {
                MessageBox.Show("Hata: " + ex.Message);
            }
        }

        private void ArayuzElemanlariniOlustur()
        {
            this.Size = new System.Drawing.Size(600, 500);
            this.Text = "YBS Performans Yönetimi Modülü (Tightly Coupled)";
            this.Load += new System.EventHandler(this.AnaForm_Load);

            dgvPerformansListesi = new DataGridView { Location = new System.Drawing.Point(20, 20), Size = new System.Drawing.Size(540, 180), SelectionMode = DataGridViewSelectionMode.FullRowSelect };
            dgvPerformansListesi.CellClick += new DataGridViewCellEventHandler(dgvPerformansListesi_CellClick);

            lblDurumBilgisi = new Label { Location = new System.Drawing.Point(20, 210), Size = new System.Drawing.Size(300, 20), Text = "Lütfen kayıt seçin..." };

            Label lblPuan = new Label { Location = new System.Drawing.Point(20, 240), Size = new System.Drawing.Size(120, 20), Text = "Yetkinlik Puanı:" };
            txtYetkinlikPuani = new TextBox { Location = new System.Drawing.Point(150, 240), Size = new System.Drawing.Size(100, 20) };

            Label lblYorum = new Label { Location = new System.Drawing.Point(20, 280), Size = new System.Drawing.Size(120, 20), Text = "Yönetici Yorumu:" };
            txtYoneticiYorumu = new TextBox { Location = new System.Drawing.Point(150, 280), Size = new System.Drawing.Size(300, 80), Multiline = true };

            btnOnaylaVeGonder = new Button { Location = new System.Drawing.Point(150, 380), Size = new System.Drawing.Size(150, 30), Text = "İK Kontrolüne Gönder" };
            btnOnaylaVeGonder.Click += new System.EventHandler(btnOnaylaVeGonder_Click);

            this.Controls.AddRange(new Control[] { dgvPerformansListesi, lblDurumBilgisi, lblPuan, txtYetkinlikPuani, lblYorum, txtYoneticiYorumu, btnOnaylaVeGonder });
        }
    }

    // ============================================================================
    // 2. İŞ MANTIĞI KATMANI: Veri tabanındaki tablolara göbekten bağımlıdır (Sıkı Bağ)
    // ============================================================================
    public class PerformansIslemleri
    {
        private string baglantiCumlesi = "Server=localhost;Database=PerformansYonetimiDB;Trusted_Connection=True;";

        // Tightly Coupled Kanıtı: Bu nesne dışarıdan enjekte edilmez, içeride mecburen yaratılır.
        public DegerlendirmeGeriBildirim GeriBildirim { get; set; }

        public PerformansIslemleri()
        {
            GeriBildirim = new DegerlendirmeGeriBildirim();
        }

        public void DegerlendirmeyiOnaylaVeGonder(int degerlendirmeID, decimal yetkinlikPuani, string yorum)
        {
            // İş Kuralları (Gereksinim Analizi Kontrolleri)
            if (yetkinlikPuani < 0 || yetkinlikPuani > 100)
                throw new Exception("Yetkinlik puanı 0-100 arasında olmalıdır!");
            if (string.IsNullOrEmpty(yorum))
                throw new Exception("Yorum alanı boş bırakılamaz!");

            using (SqlConnection conn = new SqlConnection(baglantiCumlesi))
            {
                conn.Open();

                // 1. Adım: Doğrudan SQL'deki DegerlendirmeGeriBildirim tablosuna insert atar (Sıkı Bağ)
                string feedbackSql = "INSERT INTO DegerlendirmeGeriBildirim (DegerlendirmeID, YoneticiYorumu) VALUES (@DegerlendirmeID, @YoneticiYorumu)";
                SqlCommand cmdFeedback = new SqlCommand(feedbackSql, conn);
                cmdFeedback.Parameters.AddWithValue("@DegerlendirmeID", degerlendirmeID);
                cmdFeedback.Parameters.AddWithValue("@YoneticiYorumu", yorum);
                cmdFeedback.ExecuteNonQuery();

                // 2. Adım: Senin yazdığın "sp_NihaiPuanHesapla" procedure'ünü doğrudan tetikler (Sıkı Bağ)
                SqlCommand cmdProc = new SqlCommand("sp_NihaiPuanHesapla", conn);
                cmdProc.CommandType = CommandType.StoredProcedure;
                cmdProc.Parameters.AddWithValue("@DegerlendirmeID", degerlendirmeID);
                cmdProc.ExecuteNonQuery();

                // 3. Adım: Durumu doğrudan günceller
                string updateSql = "UPDATE PerformansDegerlendirme SET DegerlendirmeDurumu = 'IKKontrolunde', GonderimTarihi = GETDATE() WHERE DegerlendirmeID = @DegerlendirmeID";
                SqlCommand cmdUpdate = new SqlCommand(updateSql, conn);
                cmdUpdate.Parameters.AddWithValue("@DegerlendirmeID", degerlendirmeID);
                cmdUpdate.ExecuteNonQuery();
            }
        }
    }

    public class DegerlendirmeGeriBildirim
    {
        public int GeriBildirimID { get; set; }
        public int DegerlendirmeID { get; set; }
        public string YoneticiYorumu { get; set; }
    }
}
