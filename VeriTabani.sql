using System;
using System.Data;
using System.Data.SqlClient;
using System.Windows.Forms;

namespace PerformansYonetimiApp
{

    public partial class AnaForm : Form
    {
  
        private int aktifYoneticiID = 2; 
        private int secilenDegerlendirmeID = 0;
        private string baglantiCumlesi = "Server=localhost;Database=PerformansYonetimiDB;Trusted_Connection=True;";

        // Arayüz Elemanları
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

        // Tight Coupling Göstergesi: Arayüz, doğrudan SQL sorgusu yazarak veri tabanına bağlanıyor.
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

        // BUTON TETİKLEYİCİSİ: Form, Business sınıfını doğrudan çağırıyor
        private void btnOnaylaVeGonder_Click(object sender, EventArgs e)
        {
            if (secilenDegerlendirmeID == 0)
            {
                MessageBox.Show("Lütfen listeden bir performans kaydı seçin!", "Hata");
                return;
            }

            try
            {
                // Sıkı Bağ Kanıtı: Somut sınıf doğrudan new'leniyor, soyutlama (interface) yok.
                PerformansIslemleri islem = new PerformansIslemleri();

                decimal yetkinlikPuani = Convert.ToDecimal(txtYetkinlikPuani.Text);
                string yorum = txtYoneticiYorumu.Text;

                // Doğrudan metodu tetikle ve DB işlemlerini başlat
                islem.DegerlendirmeyiOnaylaVeGonder(secilenDegerlendirmeID, yetkinlikPuani, yorum);

                MessageBox.Show("İşlem Başarılı! Veri tabanındaki procedure çalıştırıldı ve durum güncellendi.", "YBS Modül Bilgisi");
                BekleyenDegerlendirmeleriGetir(); // Grid listesini yenile
            }
            catch (Exception ex)
            {
                MessageBox.Show("Hata Oluştu: " + ex.Message, "İş Kuralı / SQL Hatası");
            }
        }

        // Form tasarımını kod tarafında ayağa kaldıran yardımcı metot
        private void ArayuzElemanlariniOlustur()
        {
            this.Size = new System.Drawing.Size(600, 500);
            this.Text = "YBS Performans Yönetimi Modülü (Tightly Coupled)";
            this.Load += new System.EventHandler(this.AnaForm_Load);

            dgvPerformansListesi = new DataGridView { Location = new System.Drawing.Point(20, 20), Size = new System.Drawing.Size(540, 180), SelectionMode = DataGridViewSelectionMode.FullRowSelect };
            dgvPerformansListesi.CellClick += new DataGridViewCellEventHandler(dgvPerformansListesi_CellClick);

            lblDurumBilgisi = new Label { Location = new System.Drawing.Point(20, 210), Size = new System.Drawing.Size(300, 20), Text = "Lütfen listeden bir kayıt seçin..." };

            Label lblPuan = new Label { Location = new System.Drawing.Point(20, 240), Size = new System.Drawing.Size(120, 20), Text = "Yetkinlik Puanı (0-100):" };
            txtYetkinlikPuani = new TextBox { Location = new System.Drawing.Point(150, 240), Size = new System.Drawing.Size(100, 20) };

            Label lblYorum = new Label { Location = new System.Drawing.Point(20, 280), Size = new System.Drawing.Size(120, 20), Text = "Yönetici Yorumu:" };
            txtYoneticiYorumu = new TextBox { Location = new System.Drawing.Point(150, 280), Size = new System.Drawing.Size(300, 80), Multiline = true };

            btnOnaylaVeGonder = new Button { Location = new System.Drawing.Point(150, 380), Size = new System.Drawing.Size(150, 30), Text = "İK Kontrolüne Gönder" };
            btnOnaylaVeGonder.Click += new System.EventHandler(btnOnaylaVeGonder_Click);

            this.Controls.AddRange(new Control[] { dgvPerformansListesi, lblDurumBilgisi, lblPuan, txtYetkinlikPuani, lblYorum, txtYoneticiYorumu, btnOnaylaVeGonder });
        }
    }

    // ============================================================================
    // 2. İŞ MANTIĞI VE VERİ ERİŞİMİ SINIFI (SQL Tablolarına Göbekten Bağlı)
    // ============================================================================
    public class PerformansIslemleri
    {
        private string baglantiCumlesi = "Server=localhost;Database=PerformansYonetimiDB;Trusted_Connection=True;";

        // Sıkı Bağ Bileşeni: Geri bildirim nesnesi doğrudan bu sınıfın ayrılmaz bir parçasıdır.
        public DegerlendirmeGeriBildirim GeriBildirim { get; set; }

        public PerformansIslemleri()
        {
            // Bağımlılık dışarıdan verilmiyor (DI yok), içeride doğrudan mecbur new'leniyor.
            GeriBildirim = new DegerlendirmeGeriBildirim();
        }

        public void DegerlendirmeyiOnaylaVeGonder(int degerlendirmeID, decimal yetkinlikPuani, string yorum)
        {
            // GEREKSİNİM ANALİZİ / İŞ KURALI DOĞRULAMALARI (Zorunlu alan kontrolleri)
            if (yetkinlikPuani < 0 || yetkinlikPuani > 100)
            {
                throw new Exception("Hata: Yetkinlik puanı 0 ile 100 arasında olmalıdır!");
            }
            if (string.IsNullOrEmpty(yorum))
            {
                throw new Exception("Hata: Yönetici yorum alanı boş bırakılamaz!");
            }

            using (SqlConnection conn = new SqlConnection(baglantiCumlesi))
            {
                conn.Open();

                // 1. ADIM: SQL'deki "DegerlendirmeGeriBildirim" tablosuna doğrudan veri ekleme
                string feedbackSql = @"
                    INSERT INTO DegerlendirmeGeriBildirim (DegerlendirmeID, YoneticiYorumu) 
                    VALUES (@DegerlendirmeID, @YoneticiYorumu)";
                
                SqlCommand cmdFeedback = new SqlCommand(feedbackSql, conn);
                cmdFeedback.Parameters.AddWithValue("@DegerlendirmeID", degerlendirmeID);
                cmdFeedback.Parameters.AddWithValue("@YoneticiYorumu", yorum);
                cmdFeedback.ExecuteNonQuery();

                // 2. ADIM: SQL dosendeki "sp_NihaiPuanHesapla" Stored Procedure'ünü tetikleme
                SqlCommand cmdProc = new SqlCommand("sp_NihaiPuanHesapla", conn);
                cmdProc.CommandType = CommandType.StoredProcedure;
                cmdProc.Parameters.AddWithValue("@DegerlendirmeID", degerlendirmeID);
                cmdProc.ExecuteNonQuery();

                // 3. ADIM: SQL veri kurallarına göre durumu 'IKKontrolunde' olarak güncelleme
                string updateSql = @"
                    UPDATE PerformansDegerlendirme 
                    SET DegerlendirmeDurumu = 'IKKontrolunde', GonderimTarihi = GETDATE() 
                    WHERE DegerlendirmeID = @DegerlendirmeID";

                SqlCommand cmdUpdate = new SqlCommand(updateSql, conn);
                cmdUpdate.Parameters.AddWithValue("@DegerlendirmeID", degerlendirmeID);
                cmdUpdate.ExecuteNonQuery();
            }
        }
    }

    // ============================================================================
    // 3. YARDIMCI TABLO MODELİ
    // ============================================================================
    public class DegerlendirmeGeriBildirim
    {
        public int GeriBildirimID { get; set; }
        public int DegerlendirmeID { get; set; }
        public string YoneticiYorumu { get; set; }
    }
}
